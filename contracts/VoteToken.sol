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

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IVoteToken.sol";

contract VoteToken is ERC20, ReentrancyGuard, IVoteToken {
    // key1: user address, key2: proposalId
    mapping(address => mapping(uint128 => mapping(uint128 => uint256))) private _lockedBalance;
    mapping(address => uint256) private _availableBalance;

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
    ) ERC20(_name, _symbol) {
        debondOperator = _debondOperator;
    }

    /**
    * @dev return the locked balance of an account
    * @param _account user account address
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function lockedBalanceOf(
        address _account,
        uint128 _class,
        uint128 _nonce
    ) public view override returns(uint256) {
        return _lockedBalance[_account][_class][_nonce];
    }

    /**
    * @dev return the available vote token balance of an account:
    *      available = balanOf(_account) - sum of lockedBalanceOf(_account, id)
    */
    function availableBalance(address _account) public view override returns(uint256) {
        return _availableBalance[_account];
    }

    /**
    * @dev lock vote tokens
    * @param _owner owner address of vote tokens
    * @param _spender spender address of vote tokens
    * @param _amount the amount of vote tokens to lock
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function lockTokens(
        address _owner,
        address _spender,
        uint256 _amount,
        uint128 _class,
        uint128 _nonce
    ) public override {
        require(
            _amount <= balanceOf(_owner),
            "VoteToken: not enough tokens"
        );

        require(
            allowance(_owner, _spender) <= _amount,
            "VoteToken: insufficient allowance"
        );
        
        _lockedBalance[_owner][_class][_nonce] += _amount;
        _availableBalance[_owner] = balanceOf(_owner) - _lockedBalance[_owner][_class][_nonce];
    }

    /**
    * @dev unlock vote tokens
    * @param _owner owner address of vote tokens
    * @param _amount the amount of vote tokens to lock
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function unlockTokens(
        address _owner,
        uint256 _amount,
        uint128 _class,
        uint128 _nonce
    ) public override {
        require(
            _amount <= _lockedBalance[_owner][_class][_nonce],
            "VoteToken: not enough tokens locked"
        );

        _lockedBalance[_owner][_class][_nonce] -= _amount;
        _availableBalance[_owner] = balanceOf(_owner) - _lockedBalance[_owner][_class][_nonce];
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
        _availableBalance[owner] = balanceOf(owner);
        _availableBalance[_to] = balanceOf(_to);
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
        _availableBalance[_from] = balanceOf(_from);
        _availableBalance[_to] = balanceOf(_to);
        return true;
    }

    /**
    * @dev mints vote tokens
    * @param _user the user address
    * @param _amount the amount of tokens to mint
    */
    function mintVoteToken(address _user, uint256 _amount) external override nonReentrant() {
        _mint(_user, _amount);
        _availableBalance[_user] = balanceOf(_user);
    }

    /**
    * @dev burns vote tokens
    * @param _user the user address
    * @param _amount the amount of tokens to burn
    */
    function burnVoteToken(address _user, uint256 _amount) external override nonReentrant() {
        _burn(_user, _amount);
        _availableBalance[_user] = balanceOf(_user);
    }

    /**
    * @dev set the governance contract address
    * @param _governance governance contract address
    */
    function setGovernanceContract(address _governance) external override onlyDebondOperator {
        govAddress = _governance;
    }

    /**
    * @dev get the governance contract address
    * @param gov governance contract address
    */
    function getGovernanceContract() external view returns(address gov) {
        gov = govAddress;
    }

    /**
    * @dev set the stakingDGOV contract address
    * @param _stakingDGOV stakingDGOV contract address
    */
    function setStakingDGOVContract(address _stakingDGOV) external override {
        stakingDGOV = _stakingDGOV;
    }

    /**
    * @dev get the stakingDGOV contract address
    * @param _stakingDGOV stakingDGOV contract address
    */
    function getStakingDGOVContract() external view returns(address _stakingDGOV) {
        _stakingDGOV = stakingDGOV;
    }
}
