pragma solidity ^0.8.0;

// SPDX-License-Identifier: apache 2.0
/*
    Copyright 2022 Debond Protocol <info@debond.org>
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IVoteToken.sol";
import "./interfaces/IGovStorage.sol";
import "./interfaces/IStaking.sol";
import "./interfaces/IInterestRates.sol";
import "./interfaces/IGovSharedStorage.sol";
import "./interfaces/ITransferDBIT.sol";

contract StakingDGOV is IStaking, IGovSharedStorage, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 constant private NUMBER_OF_SECONDS_IN_YEAR = 31536000;
    address public govStorageAddress;

    constructor (address _govStorageAddress) {
        govStorageAddress = _govStorageAddress;
    }
    
    /**
    * @dev stack dGoV tokens
    * @param _amount the amount of dGoV tokens to stak
    * @param _durationIndex index of the staking duration in the `voteTokenAllocation` mapping
    */
    function stakeDgovToken(
        uint256 _amount,
        uint256 _durationIndex
    ) external override {
        address staker = msg.sender;
        require(staker != address(0), "StakingDGOV: zero address");

        uint256 stakerBalance = IERC20(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).balanceOf(staker);
        require(_amount <= stakerBalance, "Debond: not enough dGov");

        // update staking data in gov storage
        (uint256 duration, uint256 amountToMint) = IGovStorage(
            govStorageAddress
        ).setStakedData(staker, _amount, _durationIndex);

        // mint vote tokens into the staker account
        IVoteToken(
            IGovStorage(govStorageAddress).getVoteTokenContract()
        ).mintVoteToken(staker, amountToMint);

        // transfer staker DGOV to staking contract
        IERC20(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).safeTransferFrom(staker, address(this), _amount);

        emit dgovStaked(staker, _amount, duration);
    }

    function unstakeDgovToken(
        uint256 _stakingCounter
    ) external override {
        address staker = msg.sender;
        require(staker != address(0), "Gov: zero address");

        StackedDGOV memory _staked = IGovStorage(
            govStorageAddress
        ).getUserStake(staker, _stakingCounter);

        require(
            block.timestamp >= _staked.startTime + _staked.duration,
            "Staking: still staking"
        );

        // update staked data in gov storage
        (uint256 amountDGOV, uint256 amountVote) = IGovStorage(
            govStorageAddress
        ).updateStake(staker, _stakingCounter);

        // burn the staker vote tokens
        IVoteToken(
            IGovStorage(govStorageAddress).getVoteTokenContract()
        ).burnVoteToken(staker, amountVote);

        // calculate the interest earned by staking DGOV
        (uint256 interest, uint256 duration) = calculateInterestEarned(staker, amountDGOV, _stakingCounter);

        // transfer DGOV to the staker
        IERC20(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).safeTransfer(staker, amountDGOV);

        // transfer DBIT interests to the staker
        ITransferDBIT(
            IGovStorage(govStorageAddress).getGovernanceAddress()
        ).transferDBITInterests(staker, interest);

        emit dgovUnstaked(staker, duration, interest);
    }

    function withDrawDbitInterest(uint256 _stakingCounter) external override {
        address staker = msg.sender;

        (
            uint256 amount,
            uint256 startTime,
            uint256 duration,
            uint256 lastWithdrawTime
        ) = IGovStorage(govStorageAddress).getStakingData(staker, _stakingCounter);

        require(amount > 0, "Gov: no DGOV staked");
        require(
            block.timestamp >= startTime && block.timestamp <= startTime + duration,
            "Gov: Unstake DGOV to get interests"
        );

        uint256 currentDuration = block.timestamp - lastWithdrawTime;
        uint256 interestEarned = estimateInterestEarned(amount, currentDuration);

        // update the last withdraw time
        IGovStorage(govStorageAddress).updateLastTimeInterestWithdraw(staker, _stakingCounter);

        // transfer DBIT interests to the staker
        ITransferDBIT(
            IGovStorage(govStorageAddress).getGovernanceAddress()
        ).transferDBITInterests(staker, interestEarned);

        emit interestWithdrawn(_stakingCounter, interestEarned);
    }

    /**
    * @dev calculate the interest earned by DGOV staker
    * @param _staker DGOV staker
    * @param _stakingCounter the staking rank
    * @param totalDuration duration  between now and last time withdraw
    */
    function calculateInterestEarned(
        address _staker,
        uint256 _amount,
        uint256 _stakingCounter
    ) public view returns(uint256 interest, uint256 totalDuration) {
        StackedDGOV memory _staked = IGovStorage(
            govStorageAddress
        ).getUserStake(_staker, _stakingCounter);

        uint256 duration = block.timestamp - _staked.lastInterestWithdrawTime;
        totalDuration = block.timestamp - _staked.startTime;
        uint256 cdp = IGovStorage(govStorageAddress).cdpDGOVToDBIT();
        uint256 benchmarkIR = IGovStorage(govStorageAddress).getBenchmarkIR();
        uint256 interestRate = stakingInterestRate(benchmarkIR, cdp);

        interest = (_amount * interestRate * duration / 1 ether) / NUMBER_OF_SECONDS_IN_YEAR;
    }

    /**
    * @dev Estimate how much Interest the user has gained since he staked dGoV
    * @param _amount the amount of DGOV staked
    * @param _duration staking duration to estimate interest from
    * @param interest the estimated interest earned so far
    */
    function estimateInterestEarned(
        uint256 _amount,
        uint256 _duration
    ) public view returns(uint256 interest) {
        uint256 cdp = IGovStorage(govStorageAddress).cdpDGOVToDBIT();
        uint256 benchmarkIR = IGovStorage(govStorageAddress).getBenchmarkIR();
        uint256 interestRate = stakingInterestRate(benchmarkIR, cdp);

        interest = (_amount * interestRate * _duration / 1 ether) / NUMBER_OF_SECONDS_IN_YEAR;
    }

    /**
    * @dev interest rate calculation for staking DGOV
    * @param _benchmarkIR benchmark interest rate
    * @param _cdp CDP of DGOV to DBIT
    */
    function stakingInterestRate(
        uint256 _benchmarkIR,
        uint256 _cdp
    ) public pure returns(uint256) {
        return _benchmarkIR * _cdp * 66 / (100 * 1 ether);
    }

    /**
    * @dev interest rate calculation for Voting rewards
    * @param _benchmarkIR benchmark interest rate
    * @param _cdp CDP of DGOV to DBIT
    */
    function votingInterestRate(
        uint256 _benchmarkIR,
        uint256 _cdp
    ) public pure returns(uint256) {        
        return _benchmarkIR * _cdp * 34 / (100 * 1 ether);
    }
}