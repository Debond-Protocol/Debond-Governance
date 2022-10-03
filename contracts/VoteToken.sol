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
import "./interfaces/IGovStorage.sol";

contract VoteToken is ERC20, ReentrancyGuard, IVoteToken {
    // key1: user address, key2: proposal class, ky3: proposal nonce
    mapping(address => mapping(uint128 => mapping(uint128 => uint256))) private _lockedBalance;
    mapping(address => uint256) private _availableBalance;
    mapping(address => uint256) private _totalLockedBalance;

    address govStorageAddress;

    modifier onlyGov {
        require(
            msg.sender == IGovStorage(govStorageAddress).getGovernanceAddress(),
            "VoteToken: only Gov"
        );
        _;
    }

    modifier onlyStaking {
        require(
            msg.sender == IGovStorage(govStorageAddress).getStakingContract()
        );
        _;
    }

    constructor(
        address _govStorageAddress
    ) ERC20("Debond Vote Token", "DVT") {
        govStorageAddress = _govStorageAddress;
    }

    /**
    * @dev return the total amount of vote tokens locked for `_account`
    * @param _account user account address
    */
    function totalLockedBalanceOf(address _account) public view returns(uint256) {
        return _totalLockedBalance[_account];
    }

    /**
    * @dev return the locked balance of an account for a given proposal
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
    ) public onlyGov {
        require(
            _amount <= balanceOf(_owner) - totalLockedBalanceOf(_owner),
            "VoteToken: not enough tokens"
        );
        require(
            allowance(_owner, _spender) <= _amount,
            "VoteToken: insufficient allowance"
        );
        
        _lockedBalance[_owner][_class][_nonce] += _amount;
        _totalLockedBalance[_owner] += _amount;
        _availableBalance[_owner] = balanceOf(_owner) - _totalLockedBalance[_owner];
    }

    /**
    * @dev update the voter balances when unlocking vote tokens
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _tokenOwner voter account address
    */
    function unlockVoteTokens(
        uint128 _class,
        uint128 _nonce,
        address _tokenOwner
    ) external onlyStaking {
        uint256 amount = lockedBalanceOf(_tokenOwner, _class, _nonce);
        require(amount > 0, "VoteToken: no vote tokens locked for this proposal");       
        
        _lockedBalance[_tokenOwner][_class][_nonce] -= amount;
        _totalLockedBalance[_tokenOwner] -= amount;
        _availableBalance[_tokenOwner] = balanceOf(_tokenOwner) - _totalLockedBalance[_tokenOwner];
    }

    /**
    * @dev transfer _amount vote tokens to `_to`
    * @param _to adrress to send tokens to
    * @param _amount the amount to transfer
    */
    function transfer(
        address _to,
        uint256 _amount
    ) public override(ERC20, IVoteToken) returns (bool) {
        address owner = msg.sender;
        require(_amount <= balanceOf(owner) - _totalLockedBalance[owner], "VoteToken: not enough tokens available");
        require(
            _to == IGovStorage(govStorageAddress).getGovernanceAddress() ||
            _to == IGovStorage(govStorageAddress).getStakingContract(),
            "VoteToken: can't transfer vote tokens"
        );

        _transfer(owner, _to, _amount);
        _availableBalance[owner] = balanceOf(owner) - _totalLockedBalance[owner];
        _availableBalance[_to] = balanceOf(_to) - _totalLockedBalance[_to];

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
        require(_amount <= balanceOf(_from) - _totalLockedBalance[_from], "VoteToken: not enough tokens available");
        require(
            _to == IGovStorage(govStorageAddress).getGovernanceAddress() ||
            _to == IGovStorage(govStorageAddress).getStakingContract(),
            "VoteToken: can't transfer vote tokens"
        );

        address spender = msg.sender;
        _spendAllowance(_from, spender, _amount);
        _transfer(_from, _to, _amount);
        _availableBalance[_from] = balanceOf(_from) - _totalLockedBalance[_from];
        _availableBalance[_to] = balanceOf(_to) - _totalLockedBalance[_to];
        return true;
    }

    /**
    * @dev mints vote tokens
    * @param _account the user address
    * @param _amount the amount of tokens to mint
    */
    function mintVoteToken(
        address _account,
        uint256 _amount
    ) external override onlyStaking nonReentrant {
        _mint(_account, _amount);
        _availableBalance[_account] = balanceOf(_account) - _totalLockedBalance[_account];
    }

    /**
    * @dev burns vote tokens
    * @param _account the user address
    * @param _amount the amount of tokens to burn
    */
    function burnVoteToken(
        address _account,
        uint256 _amount
    ) external override onlyStaking nonReentrant {
        require(_amount <= balanceOf(_account) - _totalLockedBalance[_account], "VoteToken: not enough tokens available");
        _burn(_account, _amount);
        _availableBalance[_account] = balanceOf(_account) - _totalLockedBalance[_account];
    }
}
