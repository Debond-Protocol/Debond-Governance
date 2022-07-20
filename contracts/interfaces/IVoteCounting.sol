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

import "./IGovSharedStorage.sol";

interface IVoteCounting is IGovSharedStorage {
    function hasVoted(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) external view returns(bool voted);

    function numberOfVoteTokens(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) external view returns(uint256 amountTokens);

    function getProposalVotes(
        uint128 _class,
        uint128 _nonce
    ) external view returns(
        uint256 forVotes,
        uint256 againstVotes,
        uint256 abstainVotes
    );

    function getUserInfo(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) external view returns(
        bool,
        bool,
        uint256,
        uint256
    );

    function quorumReached(
        uint128 _class,
        uint128 _nonce
    ) external view returns(bool reached);

    function voteSucceeded(
        uint128 _class,
        uint128 _nonce
    ) external view returns(bool succeeded);

    function vetoApproved(
        uint128 _class,
        uint128 _nonce
    ) external view returns(bool approved);

    function setVetoApproval(
        uint128 _class,
        uint128 _nonce,
        uint256 _vetoApproval,
        address _vetoOperator
    ) external;

    function setUserHasBeenRewarded(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) external;

    function hasBeenRewarded(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) external view returns(bool);

    function countVote(
        uint128 _class,
        uint128 _nonce,
        address _account,
        uint8 _vote,
        uint256 _weight
    ) external;

    function getVoteWeight(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) external view returns(uint256);

    function setVotingDay(
        uint128 _class,
        uint128 _nonce,
        address _voter,
        uint256 _day
    ) external;

    function getVotingDay(
        uint128 _class,
        uint128 _nonce,
        address _voter
    ) external view returns(uint256);
}