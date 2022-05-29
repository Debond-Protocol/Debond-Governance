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

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IVoteToken.sol";

import "./utils/GovernanceOwnable.sol";
contract VoteToken is ERC20, ReentrancyGuard, IVoteToken , GovernanceOwnable{
    address debondOperator;
    address govAddress;
    address stakingDGOV;

    modifier onlyGov {
        require(msg.sender == govAddress, "Gov: not governance");
        _;
    }

    modifier onlyDebondOperator {
        require(msg.sender == debondOperator, "Gov: not governance");
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        address _debondOperator
    ) ERC20(_name, _symbol) GovernanceOwnable(_debondOperator) {
        debondOperator = _debondOperator;
    }

    /**
    * @dev transfer _amount vote tokens to `_to`
    * @param _to adrress to send tokens to
    * @param _amount the amount to transfer
    */
    function transfer(address _to, uint256 _amount) public override(ERC20, IVoteToken) returns (bool) {
        require(
            _to == govAddress || _to == stakingDGOV,
            "VoteToken: can't transfer vote tokens"
        );

        address owner = _msgSender();
        _transfer(owner, _to, _amount);
        return true;
    }

    /**
    * @dev transfer _amount vote tokens from `_from` to `_to`
    * @param _from the address from which tokens are transfered
    * @param _to the address to which tokens are transfered
    * @param _amount the amount to transfer
    */
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public virtual override(ERC20, IVoteToken) returns (bool) {
        require(
            _to == govAddress || _to == stakingDGOV,
            "VoteToken: can't transfer vote tokens"
        );

        address spender = _msgSender();
        _spendAllowance(_from, spender, _amount);
        _transfer(_from, _to, _amount);
        return true;
    }

    /**
    * @dev mints vote tokens
    * @param _user the user address
    * @param _amount the amount of tokens to mint
    */
    function mintVoteToken(address _user, uint256 _amount) external nonReentrant() {
        require(msg.sender == stakingDGOV, "VoteToken:  only staking contract");
        _mint(_user, _amount);
    }

    /**
    * @dev burns vote tokens
    * @param _user the user address
    * @param _amount the amount of tokens to burn
    */
    function burnVoteToken(address _user, uint256 _amount) external nonReentrant() {
        require(msg.sender == stakingDGOV,"VoteToken:  only staking contract");
        _burn(_user, _amount);
    }

    /**
    * @dev set the governance contract address
    * @param _governance governance contract address
    */
    function setGovernanceContract(address _governance) external onlyDebondOperator {
    
    // TODO:
    // super.setGovernanceContract(_governance);
    }

    /**
    * @dev get the governance contract address
    * @param gov governance contract address
    */
    function getGovernanceContract() external view returns(address gov) {
        // returns  govAddress;
    }

    /**
    * @dev set the stakingDGOV contract address
    * @param _stakingDGOV stakingDGOV contract address
    */
    function setStakingDGOVContract(address _stakingDGOV) external {
        stakingDGOV = _stakingDGOV;
    }

    /**
    * @dev get the stakingDGOV contract address
    * @param _stakingDGOV stakingDGOV contract address
    */
    function getStakingDGOVContract() external view returns(address _stakingDGOV) {
    // 
    //    _stakingDGOV = stakingDGOV;
    }
}
