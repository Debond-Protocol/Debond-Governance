pragma solidity ^0.8.0;

// SPDX-License-Identifier: apache 2.0
/*
    Copyright 2020 Sigmoid Foundation <info@dGOV.finance>
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
import "./interfaces/INewStaking.sol";

contract NewStakingDGOV is INewStaking {
    /**
    * @dev structure that stores information on stacked dGoV
    */
    struct StackedDGOV {
        uint256 amountDGOV;
        uint256 startTime;
        uint256 duration;
    }

    mapping(address => mapping(uint256 => StackedDGOV)) internal stackedDGOV;
    mapping(address => uint256) stakingCounter;

    event dgovStacked(address staker, uint256 amount, uint256 counter);
    event dgovUnstacked(address staker, uint256 amount, uint256 counter);

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
    ) external {
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
    * @param _amount the amount of dGoV tokens to unstak
    * @param _stakingCounter the staking rank
    */
    function unstakeDgovToken(
        address _staker,
        uint256 _amount,
        uint256 _stakingCounter
    ) external {
        StackedDGOV memory _stacked = stackedDGOV[_staker][_stakingCounter];

        require(
            block.timestamp >= _stacked.startTime + _stacked.duration,
            "Staking: still staking"
        );
        require(
            _amount <= _stacked.amountDGOV,
            "Staking: Not enough dGoV staked"
        );

        // burn vote tokens and transfer back dGoV to the staker
        Ivote.burnVoteToken(_staker, _amount);
        IdGov.transfer(_staker, _amount);

        emit dgovUnstacked(_staker, _amount, _stakingCounter);
    }

    /**
    * @dev get the amount of dGoV staked by a user
    * @param _staker address of the staker
    * @param _stakingCounter the staking rank
    * @param _stakedAmount amount of dGoV staked by the user
    */
    function getStakedDGOV(address _staker, uint256 _stakingCounter) external view returns(uint256 _stakedAmount) {
        _stakedAmount = stackedDGOV[_staker][_stakingCounter].amountDGOV;
    }
}