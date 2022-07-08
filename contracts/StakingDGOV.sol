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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IStakingDGOV.sol";
import "./interfaces/IVoteToken.sol";

contract StakingDGOV is IStakingDGOV, ReentrancyGuard {
    /**
    * @dev structure that stores information on the stacked dGoV
    */
    struct StackedDGOV {
        uint256 amountDGOV;
        uint256 startTime;
        uint256 duration;
    }

    address public dbit;
    address public dGov;
    address public voteToken;
    address public debondOperator;
    address public governance;

    uint256 private interestRate;
    uint256 constant private NUMBER_OF_SECONDS_IN_YEAR = 31536000;

    mapping(address => StackedDGOV) public stackedDGOV;

    modifier onlyGov {
        require(msg.sender == governance, "Gov: not governance");
        _;
    }

    modifier onlyDebondOperator {
        require(msg.sender == debondOperator, "Gov: not governance");
        _;
    }

    constructor (
        address _dbit,
        address _dGovToken,
        address _voteToken,
        address _debondOperator,
        uint256 _interestRate
    ) {
        dbit = _dbit;
        dGov = _dGovToken;
        voteToken = _voteToken;
        debondOperator = _debondOperator;
        interestRate = _interestRate;
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
    ) external onlyGov nonReentrant() {
        IERC20 IdGov = IERC20(dGov);
        IVoteToken Ivote = IVoteToken(voteToken);
        
        uint256 stakerBalance = IdGov.balanceOf(_staker);
        require(_amount <= stakerBalance, "Debond: not enough dGov");

        stackedDGOV[_staker].startTime = block.timestamp;
        stackedDGOV[_staker].duration = _duration;
        stackedDGOV[_staker].amountDGOV += _amount;

        IdGov.transferFrom(_staker, address(this), _amount);
        Ivote.mintVoteToken(_staker, _amount);

        emit dgovStacked(_staker, _amount);
    }

    /**
    * @dev unstack dGoV tokens
    * @param _staker the address of the staker
    * @param _to the address to send the dGoV to
    * @param _amount the amount of dGoV tokens to unstak
    */
    function unstakeDgovToken(
        address _staker,
        address _to,
        uint256 _amount
    ) external onlyGov nonReentrant() {
        StackedDGOV memory _stacked = stackedDGOV[_staker];
        require(
            block.timestamp >= _stacked.startTime + _stacked.duration,
            "Staking: still staking"
        );
        require(_amount <= _stacked.amountDGOV, "Staking: Not enough dGoV staked");

        // burn the vote tokens owned by the user
        IVoteToken Ivote = IVoteToken(voteToken);
        Ivote.burnVoteToken(_staker, _amount);

        // transfer staked DGOV to the staker 
        IERC20 IdGov = IERC20(dGov);
        IdGov.transfer(_to, _amount);

        emit dgovUnstacked(_staker, _to, _amount);
    }

    /**
    * @dev set the governance contract address
    * @param _governance governance contract address
    */
    function setGovernanceContract(address _governance) external onlyDebondOperator {
        governance = _governance;
    }

    /**
    * @dev get the governance contract address
    * @param gov governance contract address
    */
    function getGovernanceContract() external view returns(address gov) {
        gov = governance;
    }

    /**
    * @dev set the interest rate of DBIT to gain when unstaking dGoV
    * @param _interest The new interest rate
    */
    function setInterestRate(uint256 _interest) external onlyDebondOperator {
        interestRate = _interest;
    }

    /**
    * @dev get the interest rate of DBIT to gain when unstaking dGoV
    * @param _interestRate The interest rate
    */
    function getInterestRate() public view returns(uint256 _interestRate) {
        _interestRate = interestRate;
    }

    /**
    * @dev get the amount of dGoV staked by a user
    * @param _user address of the user
    * @param _stakedAmount amount of dGoV staked by the user
    */
    function getStakedDGOV(address _user) external view returns(uint256 _stakedAmount) {
        _stakedAmount = stackedDGOV[_user].amountDGOV;
    }

    /**
    * @dev set the DBIT contract address
    * @param _dbit DBIT address
    */
    function setDBITContract(address _dbit) external {
        dbit = _dbit;
    }

    /**
    * @dev calculate the interest earned in DBIT
    * @param _staker the address of the dGoV staker
    * @param interest interest earned
    */
    function calculateInterestEarned(
        address _staker
    ) external view onlyGov returns(uint256 interest) {
        StackedDGOV memory staked = stackedDGOV[_staker];
        require(staked.amountDGOV > 0, "Staking: no dGoV staked");

        uint256 _interestRate = getInterestRate();

        interest = _interestRate * staked.duration / NUMBER_OF_SECONDS_IN_YEAR;
    }

    /**
    * @dev Estimate how much Interest the user has gained since he staked dGoV
    * @param _amount the amount of DBIT staked
    * @param _duration staking duration to estimate interest from
    * @param interest the estimated interest earned so far
    */
    function estimateInterestEarned(
        uint256 _amount,
        uint256 _duration
    ) external view returns(uint256 interest) {
        uint256 _interestRate = getInterestRate();
        interest = _amount * (_interestRate * _duration / NUMBER_OF_SECONDS_IN_YEAR);
    }

    /**
    * @dev update the stakedDGOV struct after a staker unstake dGoV
    * @param _staker the address of the staker
    * @param _amount the amount of dGoV token that have been unstake
    * @param updated true if the struct has been updated, false otherwise
    */
    function updateStakedDGOV(
        address _staker,
        uint256 _amount
    ) external onlyGov returns(bool updated) {
        stackedDGOV[_staker].amountDGOV -= _amount;

        updated = true;
    }
}
