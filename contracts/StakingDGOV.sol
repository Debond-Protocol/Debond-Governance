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
import "./interfaces/IGovSharedStorage.sol";
import "@debond-protocol/debond-apm-contracts/interfaces/IAPM.sol";
import "@debond-protocol/debond-token-contracts/interfaces/IDebondToken.sol";




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
    ) external override nonReentrant {
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
    ) external override nonReentrant {
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
        (uint256 interest, uint256 duration) = _calculateInterestEarned(amountDGOV, _stakingCounter);

        // transfer DGOV to the staker
        IERC20(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).safeTransfer(staker, amountDGOV);

        // transfer DBIT interests to the staker
        _withdrawDBIT(staker, interest);

        emit dgovUnstaked(staker, duration, interest);
    }

    function withdrawDbitInterest(uint256 _stakingCounter) external override nonReentrant {
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
            "Staking: Unstake DGOV to get interests"
        );

        uint256 currentDuration = block.timestamp - lastWithdrawTime;
        uint256 interestEarned = estimateInterestEarned(amount, currentDuration);

        // update the last withdraw time
        IGovStorage(govStorageAddress).updateLastTimeInterestWithdraw(staker, _stakingCounter);

        // transfer DBIT interests to the staker
        _withdrawDBIT(staker, interestEarned);

        emit interestWithdrawn(_stakingCounter, interestEarned);

    }

    function unlockVotes(uint128 _class, uint128 _nonce) public nonReentrant {
        address tokenOwner = msg.sender;
        require(tokenOwner != address(0), "Gov: zero address");

        Proposal memory proposal = IGovStorage(govStorageAddress).getProposalStruct(_class, _nonce);
        ProposalStatus status = IGovStorage(govStorageAddress).getProposalStatus(_class, _nonce);
        require(
            status == ProposalStatus.Canceled ||
            status == ProposalStatus.Succeeded ||
            status == ProposalStatus.Defeated ||
            status == ProposalStatus.Executed,
            "Staking: still voting"
        );

        // proposer locks vote tokens by submiting the proposal, and may not have voted
        if (tokenOwner != proposal.proposer) {
            require(
                IVoteToken(
                    IGovStorage(govStorageAddress).getVoteTokenContract()
                ).lockedBalanceOf(tokenOwner, _class, _nonce) > 0,
                "Staking: no DGOV staked or haven't voted"
            );
        }

        require(
            !IGovStorage(govStorageAddress).hasBeenRewarded(_class, _nonce, tokenOwner),
            "Staking: already rewarded"
        );

        IGovStorage(govStorageAddress).setUserHasBeenRewarded(_class, _nonce, tokenOwner);

        uint256 reward = _calculateVotingReward(_class, _nonce, tokenOwner);

        // unlock vote tokens
        IVoteToken(
            IGovStorage(govStorageAddress).getVoteTokenContract()
        ).unlockVoteTokens(_class, _nonce, tokenOwner);

        // transfer DBIT reward to the voter
        _withdrawDBIT(tokenOwner, reward);

        emit voteTokenUnlocked(_class, _nonce, tokenOwner);
    }

    /**
    * @dev calculate the interest earned by DGOV staker
    * @param _stakingCounter the staking rank
    * @param totalDuration duration  between now and last time withdraw
    */
    function _calculateInterestEarned(
        uint256 _amount,
        uint256 _stakingCounter
    ) private view returns (uint256 interest, uint256 totalDuration) {
        address staker = msg.sender;
        StackedDGOV memory _staked = IGovStorage(
            govStorageAddress
        ).getUserStake(staker, _stakingCounter);

        uint256 duration = block.timestamp - _staked.lastInterestWithdrawTime;
        totalDuration = block.timestamp - _staked.startTime;
        uint256 cdp = _cdpDGOVToDBIT();
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
    ) public view returns (uint256 interest) {
        uint256 cdp = _cdpDGOVToDBIT();
        uint256 benchmarkIR = IGovStorage(govStorageAddress).getBenchmarkIR();
        uint256 interestRate = stakingInterestRate(benchmarkIR, cdp);

        interest = (_amount * interestRate * _duration / 1 ether) / NUMBER_OF_SECONDS_IN_YEAR;
    }

    function _calculateVotingReward(
        uint128 _class,
        uint128 _nonce,
        address _tokenOwner
    ) private view returns (uint256 reward) {
        uint256 benchmarkIR = IGovStorage(govStorageAddress).getBenchmarkIR();
        uint256 cdp = _cdpDGOVToDBIT();
        uint256 rewardRate = votingInterestRate(benchmarkIR, cdp);
        uint256 voteWeight = IGovStorage(govStorageAddress).getVoteWeight(_class, _nonce, _tokenOwner);

        uint256 _reward;

        for (uint256 i = 1; i <= IGovStorage(govStorageAddress).getNumberOfVotingDays(_class); i++) {
            _reward += (1 ether * 1 ether) / IGovStorage(govStorageAddress).getTotalVoteTokenPerDay(_class, _nonce, i);
        }

        reward = voteWeight * rewardRate * _reward / (36500 * 1 ether * 1 ether);
    }

    /**
    * @dev interest rate calculation for staking DGOV
    * @param _benchmarkIR benchmark interest rate
    * @param _cdp CDP of DGOV to DBIT
    */
    function stakingInterestRate(
        uint256 _benchmarkIR,
        uint256 _cdp
    ) public pure returns (uint256) {
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
    ) public pure returns (uint256) {
        return _benchmarkIR * _cdp * 34 / (100 * 1 ether);
    }

    function _withdrawDBIT(address _to, uint256 _amount) private {
        IAPM(
            IGovStorage(govStorageAddress).getAPMAddress()
        ).removeLiquidity(_to, IGovStorage(govStorageAddress).getDBITAddress(), _amount);
    }

    function _cdpDGOVToDBIT() private view returns(uint256) {
        uint256 dgovTotalSupply = IDebondToken(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).getTotalCollateralisedSupply();

        return 100 ether + ((dgovTotalSupply / 33333)**2 / 1 ether);
    }
}
