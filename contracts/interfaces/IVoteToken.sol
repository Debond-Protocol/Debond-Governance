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

import "../interfaces/IGovSharedStorage.sol";

interface IVoteToken is IGovSharedStorage {
    /**
    * @dev mints  vote Token tokens to the address of a user
    */
    function mintVoteToken(
        address _user,
        uint256 _amount
    ) external;

    /**
    * @dev burns vote Token tokens from the address of a user
    */
    function burnVoteToken(
        address _user,
        uint256 _amount
    ) external;

    /**
    * @dev transfer _amount vote tokens to `_to`
    */
    function transfer(
        address _to,
        uint256 _amount
    ) external returns (bool);

    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) external returns (bool);

    /**
    * @dev return the total locked balance of an account
    */
    function totalLockedBalanceOf(
        address _account
    ) external view returns(uint256);

    /**
    * @dev return the locked balance of an account for a given proposal
    */
    function lockedBalanceOf(
        address _account,
        uint128 _class,
        uint128 _nonce
    ) external view returns(uint256);

    function unlockVoteTokens(
        uint128 _class,
        uint128 _nonce,
        address _tokenOwner
    ) external;

    /**
    * @dev lock vote tokens 
    */
    function lockTokens(
        address _owner,
        address _spender,
        uint256 _amount,
        uint128 _class,
        uint128 _nonce
    ) external;

    /**
    * @dev return the available vote token balance of an account
    */
    function availableBalance(
        address _account
    ) external view returns(uint256);
}
