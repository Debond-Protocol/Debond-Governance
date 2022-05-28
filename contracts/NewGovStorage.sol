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

contract NewGovStorage {
    struct  Proposal {
        uint256 id;
        uint256 startTime;
        uint256 endTime;
        ProposalStatus status;
        ProposalApproval approvalMode;
    }

    struct ProposalClass {
        uint128 nonce;
    }

    address public debondOperator;

    uint256 public voteStart;
    uint256 public votePeriod;

    enum ProposalStatus {
        Active,
        Canceled,
        Pending,
        Defeated,
        Succeeded,
        Executed
    }

    enum ProposalApproval {
        NoVote,
        Approve,
        VoteAndVeto
    }

    mapping(uint128 => ProposalClass) proposalClass;
    mapping(uint128 => mapping(uint128 => Proposal)) proposal;

    modifier onlyDebondOperator {
        require(msg.sender == debondOperator, "Gov: Need rights");
        _;
    }
}