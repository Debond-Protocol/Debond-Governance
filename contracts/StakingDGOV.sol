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
import "./interfaces/IVoteToken.sol";
import "./interfaces/IStaking.sol";

contract StakingDGOV is IStaking {
    /**
    * @dev structure that stores information on stacked dGoV
    */
    struct StackedDGOV {
        uint256 amountDGOV;
        uint256 startTime;
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
    
    IERC20 IdGov;
    IVoteToken Ivote;

    constructor (
        address _dgovToken,
        address _voteToken
    ) {
        dGov = _dgovToken;
        voteToken = _voteToken;
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
    ) external override {
        uint256 stakerBalance = IdGov.balanceOf(_staker);
        require(_amount <= stakerBalance, "Debond: not enough dGov");

        uint256 counter = stakingCounter[_staker];

        stackedDGOV[_staker][counter + 1].startTime = block.timestamp;
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
    ) external override returns(uint256 unstakedAmount) {
        StackedDGOV memory _staked = stackedDGOV[_staker][_stakingCounter];

        require(
            block.timestamp >= _staked.startTime + _staked.duration,
            "Staking: still staking"
        );

        require(_staked.amountDGOV > 0, "Staking: no dGoV staked");

        unstakedAmount = _staked.amountDGOV;
        _staked.amountDGOV = 0;

        // burn vote tokens and transfer back dGoV to the staker
        Ivote.burnVoteToken(_staker, unstakedAmount);
        IdGov.transfer(_staker, unstakedAmount);

        emit dgovUnstacked(_staker, unstakedAmount, _stakingCounter);
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
    ) external view override returns(uint256 interest) {
        StackedDGOV memory _staked = stackedDGOV[_staker][_stakingCounter];
        require(_staked.amountDGOV > 0, "Staking: not dGoV staked");

        interest = (_interestRate * _staked.duration * 1 ether) / (100 * NUMBER_OF_SECONDS_IN_YEAR);
    }

    /**
    * @dev get the amount of dGoV staked by a user
    * @param _staker address of the staker
    * @param _stakingCounter the staking rank
    * @param _stakedAmount amount of dGoV staked by the user
    */
    function getStakedDGOV(address _staker, uint256 _stakingCounter) external view override returns(uint256 _stakedAmount) {
        _stakedAmount = stackedDGOV[_staker][_stakingCounter].amountDGOV;
    }
}
