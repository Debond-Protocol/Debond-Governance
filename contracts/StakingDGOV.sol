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
    mapping(address => mapping(uint256 => StackedDGOV)) stackedDGOV;
    mapping(address => uint256) public stakingCounter;
    mapping(uint256 => VoteTokenAllocation) private voteTokenAllocation;

    StackedDGOV[] private _totalStackedDGOV;
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

    function transferDGOV(
        address _staker,
        uint256 _amountDGOV
    ) external override onlyGov {
        require(
            IERC20(
                IGovStorage(govStorageAddress).getDGOVAddress()
            ).transfer(_staker, _amountDGOV)
        );
    }

    /**
    * @dev set last interest withdraw time for DGOV staked
    * @param _staker DGOV staker
    * @param _stakingCounter the staking rank
    */
    function setLastTimeInterestWithdraw(
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
    * @param _amount amount of staked DGOV
    * @param _lastInterestWithdrawTime last withdraw time
    */
    function calculateInterestEarned(
        uint256 _amount,
        uint256 _lastInterestWithdrawTime
    ) external view returns(uint256 interest) {
        uint256 interestRate = stakingInterestRate();

        uint256 duration = block.timestamp - _lastInterestWithdrawTime;

        // DGOV balance of the staking contract
        uint256 stakingSupply = IERC20(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).balanceOf(address(this));

        // (amountStaked / balanceOf(stakingContract)) * interestRate
        interest = (_amount * interestRate * duration) / (100 * NUMBER_OF_SECONDS_IN_YEAR * stakingSupply);
    }

    function votingInterestRate() public view returns(uint256) {
        uint256 cdpPrice = IGovStorage(govStorageAddress).cdpDGOVToDBIT();
        uint256 benchmarkInterestRate = IGovStorage(govStorageAddress).getBenchmarkIR();
        
        return benchmarkInterestRate * cdpPrice * 34 / 100;
    }

    /**
    * @dev return the daily interest rate for staking DGOV (in percent)
    */
    function stakingInterestRate() public view returns(uint256) {
        uint256 cdpPrice = IGovStorage(govStorageAddress).cdpDGOVToDBIT();
        uint256 benchmarkInterestRate = IGovStorage(govStorageAddress).getBenchmarkIR();
        
        return benchmarkInterestRate * cdpPrice * 66 / 100;
    }

    /**
    * @dev get the amount of dGoV staked by a user
    * @param _staker address of the staker
    * @param _stakingCounter the staking rank
    * @param _stakedAmount amount of dGoV staked by the user
    */
    function getStakedDGOVAmount(
        address _staker,
        uint256 _stakingCounter
    ) external view returns(uint256 _stakedAmount) {
        _stakedAmount = stackedDGOV[_staker][_stakingCounter].amountDGOV;
    }

    function getAvailableVoteTokens(
        address _staker,
        uint256 _stakingCounter
    ) external view returns(uint256 _voteTokens) {
        _voteTokens = stackedDGOV[_staker][_stakingCounter].amountVote;
    }

    function getStartTimeDurationAndLastWithdrawTime(
        address _staker,
        uint256 _stakingCounter
    ) external view returns(uint256 startTime, uint256 duration, uint256 lastWithdrawTime) {
        (
            startTime,
            duration,
            lastWithdrawTime
        ) =
        (
            stackedDGOV[_staker][_stakingCounter].startTime,
            stackedDGOV[_staker][_stakingCounter].duration,
            stackedDGOV[_staker][_stakingCounter].lastInterestWithdrawTime
        );
    }
}
