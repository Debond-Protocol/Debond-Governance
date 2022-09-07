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
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IVoteToken.sol";
import "./interfaces/IGovStorage.sol";
import "./interfaces/IStaking.sol";
import "./interfaces/IInterestRates.sol";

contract StakingDGOV is IStaking, ReentrancyGuard {
    /**
    * @dev structure that stores information on stacked dGoV
    */
    struct StackedDGOV {
        uint256 amountDGOV;
        uint256 amountVote;
        uint256 startTime;
        uint256 lastInterestWithdrawTime;
        uint256 duration;
    }

    struct VoteTokenAllocation {
        uint256 duration;
        uint256 allocation;
    }

    // key1: staker address, key2: staking rank of the staker
    mapping(address => mapping(uint256 => StackedDGOV)) internal stackedDGOV;
    mapping(address => uint256) public stakingCounter;
    mapping(uint256 => VoteTokenAllocation) private voteTokenAllocation;

    mapping(address => StackedDGOV[]) _totalStackedDGOV;
    VoteTokenAllocation[] private _voteTokenAllocation;

    uint256 constant private NUMBER_OF_SECONDS_IN_YEAR = 31536000;
    address public govStorageAddress;

    modifier onlyGov() {
        require(
            msg.sender == IGovStorage(govStorageAddress).getGovernanceAddress(),
            "StakingDGOV: only governance"
        );
        _;
    }

    modifier onlyProposalLogic {
        require(
            msg.sender == IGovStorage(govStorageAddress).getProposalLogicContract(),
            "StakingDGOV: permission denied"
        );
        _;
    }

    constructor (
        address _govStorageAddress
    ) {
        govStorageAddress = _govStorageAddress;

        // for tests only
        voteTokenAllocation[0].duration = 4;
        voteTokenAllocation[0].allocation = 3000000000000000;

        //voteTokenAllocation[0].duration = 4 weeks;
        //voteTokenAllocation[0].allocation = 3000000000000000;
        _voteTokenAllocation.push(voteTokenAllocation[0]);

        voteTokenAllocation[1].duration = 12 weeks;
        voteTokenAllocation[1].allocation = 3653793637913968;
        _voteTokenAllocation.push(voteTokenAllocation[1]);

        voteTokenAllocation[2].duration = 24 weeks;
        voteTokenAllocation[2].allocation = 4578397467645146;
        _voteTokenAllocation.push(voteTokenAllocation[2]);

        voteTokenAllocation[3].duration = 48 weeks;
        voteTokenAllocation[3].allocation = 5885984743473081;
        _voteTokenAllocation.push(voteTokenAllocation[3]);

        voteTokenAllocation[4].duration = 96 weeks;
        voteTokenAllocation[4].allocation = 7735192402935436;
        _voteTokenAllocation.push(voteTokenAllocation[4]);

        voteTokenAllocation[5].duration = 144 weeks;
        voteTokenAllocation[5].allocation = 10000000000000000;
        _voteTokenAllocation.push(voteTokenAllocation[5]);
    }
    
    /**
    * @dev stack dGoV tokens
    * @param _staker the address of the staker
    * @param _amount the amount of dGoV tokens to stak
    * @param _durationIndex index of the staking duration in the `voteTokenAllocation` mapping
    */
    function stakeDgovToken(
        address _staker,
        uint256 _amount,
        uint256 _durationIndex
    ) external override onlyGov returns(uint256 duration, uint256 _amountToMint) {
        uint256 counter = stakingCounter[_staker];

        stackedDGOV[_staker][counter + 1].startTime = block.timestamp;
        stackedDGOV[_staker][counter + 1].lastInterestWithdrawTime = block.timestamp;
        stackedDGOV[_staker][counter + 1].duration = voteTokenAllocation[_durationIndex].duration;
        stackedDGOV[_staker][counter + 1].amountDGOV += _amount;
        stackedDGOV[_staker][counter + 1].amountVote += _amount * voteTokenAllocation[_durationIndex].allocation / 10**16;
        stakingCounter[_staker] = counter + 1;
        
        _totalStackedDGOV[_staker].push(stackedDGOV[_staker][counter + 1]);

        _amountToMint = _amount * voteTokenAllocation[_durationIndex].allocation / 10**16;
        duration = voteTokenAllocation[_durationIndex].duration;
    }

    /**
    * @dev unstack dGoV tokens
    * @param _staker the address of the staker
    * @param _stakingCounter the staking rank
    */
    function transferDgov(
        address _staker,
        uint256 _stakingCounter
    ) external override onlyGov nonReentrant returns(uint256 amountDGOV, uint256 amountVote) {
        StackedDGOV memory _staked = stackedDGOV[_staker][_stakingCounter];

        require(
            block.timestamp >= _staked.startTime + _staked.duration,
            "Staking: still staking"
        );

        amountDGOV = _staked.amountDGOV;
        amountVote = _staked.amountVote;
        _staked.amountDGOV = 0;
        _staked.amountVote = 0;

        IERC20(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).transfer(_staker, amountDGOV);
    }

    /**
    * @dev set last interest withdraw time for DGOV staked
    * @param _staker DGOV staker
    * @param _stakingCounter the staking rank
    */
    function updateLastTimeInterestWithdraw(
        address _staker,
        uint256 _stakingCounter
    ) external onlyGov {
        StackedDGOV memory _staked = stackedDGOV[_staker][_stakingCounter];
        require(_staked.amountDGOV > 0, "Staking: no DGOV staked");

        require(
            block.timestamp >= _staked.lastInterestWithdrawTime &&
            block.timestamp < _staked.startTime + _staked.duration,
            "Staking: Unstake DGOV to withdraw interest"
        );

        stackedDGOV[_staker][_stakingCounter].lastInterestWithdrawTime = block.timestamp;
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
        StackedDGOV memory _staked = stackedDGOV[_staker][_stakingCounter];
        uint256 duration = block.timestamp - _staked.lastInterestWithdrawTime;
        totalDuration = block.timestamp - _staked.startTime;
        uint256 cdp = IGovStorage(govStorageAddress).cdpDGOVToDBIT();
        uint256 benchmarkIR = IGovStorage(govStorageAddress).getBenchmarkIR();
        
        uint256 interestRate = IInterestRates(
            IGovStorage(govStorageAddress).getInterestRatesContract()
        ).stakingInterestRate(benchmarkIR, cdp);

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
        
        uint256 interestRate = IInterestRates(
            IGovStorage(govStorageAddress).getInterestRatesContract()
        ).stakingInterestRate(benchmarkIR, cdp);

        interest = (_amount * interestRate * _duration / 1 ether) / NUMBER_OF_SECONDS_IN_YEAR;
    }

    function getVoteTokenAllocation() public view returns(VoteTokenAllocation[] memory) {
        return _voteTokenAllocation;
    }

    function getStakedDOVOf(address _account) public view returns(StackedDGOV[] memory) {
        return _totalStackedDGOV[_account];
    }
 
    function getAvailableVoteTokens(
        address _staker,
        uint256 _stakingCounter
    ) external view returns(uint256 _voteTokens) {
        _voteTokens = stackedDGOV[_staker][_stakingCounter].amountVote;
    }

    function getStakingData(
        address _staker,
        uint256 _stakingCounter
    ) public view returns(
        uint256 _stakedAmount,
        uint256 startTime,
        uint256 duration,
        uint256 lastWithdrawTime
    ) {
        return (
            stackedDGOV[_staker][_stakingCounter].amountDGOV,
            stackedDGOV[_staker][_stakingCounter].startTime,
            stackedDGOV[_staker][_stakingCounter].duration,
            stackedDGOV[_staker][_stakingCounter].lastInterestWithdrawTime
        );
    }
}