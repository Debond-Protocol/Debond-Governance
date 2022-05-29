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

interface IVoteToken {
    /**
    * @dev mints  vote  tokens to the address of a user (those staking dGOV )
    * @notice  to be called only by the stakingContract.stakedGOV() to mint tokens after calculation of rewards
    * @param _user address of the user intended to get VoteToken
    * @param _amount is the amount of tokens to be received
    */
    function mintVoteToken(address _user, uint256 _amount) external;

    /**
    * @dev burns vote Token tokens from the address of a user . 
    * @notice  to be called only by stakingContract.unstakedGOV() in order to recuperate the remaining Vote Tokens into the 
    * @param _user address of the user intended to get dGOV token . 
    * @param _amount is the amount of tokens to be received
    */
    function burnVoteToken(address _user, uint256 _amount) external;

    /**
    * @dev set the governance contract address
    * @notice to be managed by the governanceOwnable with the address initialized by CSO . 
    * @param _governance is the  new EOA handling the governance.
    */
    function setGovernanceContract(address _governance) external;

    /**
    * @dev set the  current / new stakingDGOV contract address. 
    * @notice used first time to set the corresponding StakingDGOV contract and then called by the proposal contract for changing the staking operations.
    * @param _stakingSGOV is the address of the new staking contract 
    */
    function setStakingDGOVContract(address _stakingSGOV) external;

    /**
    * @dev transfer _amount vote tokens from msg.sender () to destination address 
    * @notice this will be restricted to be transferred between the owner of dGOV who incurred interest on his Vote token to the stakingContract
    * @param _to is the destination staking Contract address deployed by d/bond 
    * @param _amount is the amount of the tokens to be transferred
    */
    function transfer(address _to, uint256 _amount) external returns (bool);

     /**
    * @dev transfer _amount vote tokens from '_from' address   to  '_to' address.
    * @notice this will be restricted to be transferred between the staking and governance contracts only .
    * @param _from is the source address consisting of the Vote tokens . 
    * @param _to is the destination staking Contract address deployed by d/bond 
    * @param _amount is the amount of the tokens to be transferred. 
    */
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) external returns (bool);
}