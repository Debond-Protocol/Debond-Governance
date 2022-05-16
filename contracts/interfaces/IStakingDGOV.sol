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

interface IStakingDGOV {
    /**
    * @dev emitted when dGoV tokens are stacked
    */
    event dgovStacked(address _staker, uint256 _amount);

    /**
    * @dev emitted when dGoV tokens are unstacked
    */
    event dgovUnstacked(address _staker, address _to, uint256 _amount);

    /**
    * @dev stake dGoV tokens and receive staking tokens
    */
    function stakeDgovToken(address _staker, uint256 _amount, uint256 _duration) external;

    /**
    * @dev unstake dGoV tokens and burn staking tokens
    */
    function unstakeDgovToken(address _staker, address _to, uint256 _amount) external;

    /**
    * @dev set the governance contract address
    * @param _governance contract address
    */
    function setGovernanceContract(address _governance) external;

    /**
    * @dev get the governance contract address
    */
    function getGovernanceContract() external view returns(address gov);

    /**
    * @dev get the amount of dGoV staked by a user
    */
    function getStakedDGOV(address _user) external view returns(uint256 _stakedAmount);

    /**
    * @dev set the DBIT interest rate APY
    * @param _dbitInterest new interest rate
    */
    function setInterestRate(uint256 _dbitInterest) external;

    /**
    * @dev calculate the interest earned in DBIT
    */
    function calculateInterestEarned(address _staker) external view returns(uint256 interest);

    /**
    * @dev update the StakedDGOV struct when a user unstake their dGoV
    */
    function updateStakedDGOV(address _staker, uint256 _amount) external returns(bool updated);

    /**
    * @param _interestRate interest rate
    */
    function getInterestRate() external view returns(uint256 _interestRate);

    /**
    * @dev set the DBIT contract address
    */
    function setDBITContract(address _dbit) external;
}