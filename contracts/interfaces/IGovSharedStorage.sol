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

interface IGovSharedStorage {
    struct  Proposal {
        uint256 startTime;
        uint256 endTime;
        address proposer;
        ProposalStatus status;
        ProposalApproval approvalMode;
        address[] targets;
        uint256[] values;
        bytes[] calldatas;
        string title;
        bytes32 descriptionHash;
    }

    struct User {
        bool hasVoted;
        bool hasBeenRewarded;
        uint256 weight;
        uint256 votingDay;
    }

    struct ProposalVote {
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 vetoApproval;
        mapping(address => User) user;
    }

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

    enum VoteType {
        For,
        Against,
        Abstain
    }

    enum InterestRateType {
        FixedRate,
        FloatingRate
    }

    /**
     * @dev Emitted when a proposal is created.
     */
     event ProposalCreated(
        uint128 class,
        uint128 nonce,
        uint256 startVoteTime,
        uint256 endVoteTime,
        address proposer,
        address[] targets,
        uint256[] values,
        bytes[] calldatas,
        string title,
        bytes32 descriptionHash,
        ProposalApproval approval
    );

    /**
    * @dev Emitted when a proposal is executed
    */
    event ProposalExecuted(uint128, uint128);

    event dgovUnstaked(uint256 amountDGOV, uint256 counter, uint256 duration);

    event inetrestWithdrawn(uint256 counter, uint256 duration);
}