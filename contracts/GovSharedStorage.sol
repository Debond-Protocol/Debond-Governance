pragma solidity ^0.8.0;

// SPDX-License-Identifier: apache 2.0
/*
    Copyright 2020 Sigmoid Foundation <info@SGM.finance>
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

abstract contract GovSharedStorage {
    struct ProposalNonce {
        uint128 nonce;
    }

    struct VotingReward {
        uint256 numberOfVotingDays;
        uint256 numberOfDBITDistributedPerDay;
    }

    // link proposal class to class info
    mapping(uint128 => uint256[6]) public proposalClassInfo;

    // links proposal class to proposal nonce
    mapping(uint128 => uint128) public proposalNonce;

    // vote rewards info
    mapping(uint128 => VotingReward) public votingReward;

    // total vote tokens collected per day for a given proposal
    // key1: proposal class, key2: proposal nonce, key3: voting day (1, 2, 3, etc.)
    mapping(uint128 => mapping(uint128 => mapping(uint256 => uint256))) public totalVoteTokenPerDay;
}