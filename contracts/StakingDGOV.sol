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

interface IUpdatable {
    function updateGovernance(
        address _governanceAddress
    ) external;
}

contract StakingExecutable is IUpdatable {
    address governance;
    address executable;

    modifier onlyExec {
        require(msg.sender == executable, "Bank: only exec");
        _;
    }
    
    function updateGovernance(
        address _governanceAddress
    ) external onlyExec {
        governance = _governanceAddress;
    }

    function getGovernanceAddress() public view returns(address) {
        return governance;
    }
}

contract StakingDGOV is IStaking, StakingExecutable, ReentrancyGuard {
    /**
    * @dev structure that stores information on stacked dGoV
    */
    struct StackedDGOV {
        uint256 amountDGOV;
        uint256 startTime;
        uint256 lastInterestWithdrawTime;
        uint256 duration;
    }

    // key1: staker address, key2: staking rank of the staker
    mapping(address => mapping(uint256 => StackedDGOV)) internal stackedDGOV;
    mapping(address => uint256) public stakingCounter;

    event dgovStacked(address staker, uint256 amount, uint256 counter);
    event dgovUnstacked(address staker, uint256 amount, uint256 counter);

    uint256 constant private NUMBER_OF_SECONDS_IN_YEAR = 31536000;

    address public dGov;
    address public voteToken;
    address public proposalLogic;
    address public govStorageAddress;

    modifier onlyGov() {
        require(msg.sender == governance, "StakingDGOV: only governance");
        _;
    }

    modifier onlyProposalLogic {
        require(msg.sender == proposalLogic, "StakingDGOV: permission denied");
        _;
    }
    
    IERC20 IdGov;
    IVoteToken Ivote;

    constructor (
        address _dgovToken,
        address _voteToken,
        address _governance,
        address _proposalLogic,
        address _govStorageAddress,
        address _executable
    ) {
        dGov = _dgovToken;
        voteToken = _voteToken;
        governance = _governance;
        executable = _executable;
        proposalLogic = _proposalLogic;
        govStorageAddress = _govStorageAddress;
        IdGov = IERC20(_dgovToken);
        Ivote = IVoteToken(_voteToken);
    }
    
    /**
    * @dev stack dGoV tokens
    * @param _staker the address of the staker
    * @param _amount the amount of dGoV tokens to stak
    * @param _duration the staking period
    */
    function stakeDgovToken(
        address _staker,
        uint256 _amount,
        uint256 _duration
    ) external override onlyGov {
        require(_staker != address(0), "StakingDGOV: zero address");

        uint256 stakerBalance = IdGov.balanceOf(_staker);
        require(_amount <= stakerBalance, "Debond: not enough dGov");

        uint256 counter = stakingCounter[_staker];

        stackedDGOV[_staker][counter + 1].startTime = block.timestamp;
        stackedDGOV[_staker][counter + 1].lastInterestWithdrawTime = block.timestamp;
        stackedDGOV[_staker][counter + 1].duration = _duration;
        stackedDGOV[_staker][counter + 1].amountDGOV += _amount;
        stakingCounter[_staker] = counter + 1;

        IdGov.transferFrom(_staker, address(this), _amount);
        Ivote.mintVoteToken(_staker, _amount);

        emit dgovStacked(_staker, _amount, counter + 1);
    }

    /**
    * @dev unstack dGoV tokens
    * @param _staker the address of the staker
    * @param _stakingCounter the staking rank
    */
    function unstakeDgovToken(
        address _staker,
        uint256 _stakingCounter
    ) external override onlyProposalLogic nonReentrant returns(uint256 unstakedAmount) {
        StackedDGOV memory _staked = stackedDGOV[_staker][_stakingCounter];
        require(_staked.amountDGOV > 0, "Staking: no dGoV staked");

        require(
            block.timestamp >= _staked.startTime + _staked.duration,
            "Staking: still staking"
        );

        unstakedAmount = _staked.amountDGOV;
        _staked.amountDGOV = 0;

        // burn vote tokens and transfer back dGoV to the staker
        Ivote.burnVoteToken(_staker, unstakedAmount);
        IdGov.transfer(_staker, unstakedAmount);

        emit dgovUnstacked(_staker, unstakedAmount, _stakingCounter);
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
    * @param _staker DGOV staker
    * @param _stakingCounter the staking rank
    * @param _interestRate interest rate (in ether unit: 1E+18)
    */
    function calculateInterestEarned(
        address _staker,
        uint256 _stakingCounter,
        uint256 _interestRate
    ) external view returns(uint256 interest, uint256 totalDuration) {
        StackedDGOV memory _staked = stackedDGOV[_staker][_stakingCounter];

        uint256 duration = block.timestamp - _staked.lastInterestWithdrawTime;
        totalDuration = block.timestamp - _staked.startTime;

        interest = (_interestRate * duration) / (100 * NUMBER_OF_SECONDS_IN_YEAR);
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
