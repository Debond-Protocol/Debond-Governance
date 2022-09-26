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
        uint256[] ethValues;
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
        bool vetoed;
        mapping(address => User) user;
    }

    struct AllocatedToken {
        uint256 allocatedDBITMinted;
        uint256 allocatedDGOVMinted;
        uint256 dbitAllocationPPM;
        uint256 dgovAllocationPPM;
    }

    struct ProposalNonce {
        uint128 nonce;
    }

    enum ProposalStatus {
        Active,
        Canceled,
        Pending,
        Defeated, // TODO rename that status to FAILED maybe
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
        uint128 nonce
    );

    struct StackedDGOV {
        uint256 amountDGOV;
        uint256 amountVote;
        uint256 startTime;
        uint256 lastInterestWithdrawTime;
        uint256 duration;
    }

    struct VoteTokenAllocation {
        uint256 duration;
        uint256 allocation;
    }

    struct UserVoteData {
        address voter;
        uint256 weight;
        uint8 vote;
    }





    /**
    * @dev Emitted when a proposal is executed
    */
    event ProposalExecuted(uint128 class, uint128 nonce);

    event ProposalCanceled(uint128 class, uint128 nonce);

    event interestWithdrawn(uint256 counter, uint256 duration);

    event voted(uint128 class, uint128 nonce, address voter, uint256 stakeCounter, uint256 amountTokens);

    event vetoUsed(uint128 class, uint128 nonce);

    event dgovStaked(address staker, uint256 amount, uint256 duration);

    event dgovUnstaked(address staker, uint256 duration, uint256 interest);

    event voteTokenUnlocked(uint128 class, uint128 nonce, address tokenOwner);

    event dgovMaxSupplyUpdated(uint256 newMaxSupply);

    event maxAllocationSet(address token, uint256 newAllocation);

    event maxAirdropSupplyUpdated(address token, uint256 newSupply);

    event allocationTokenMinted(address token, address to, uint256 amount);

    event benchmarkUpdated(uint256 newBenchmark);

    event newBondClassCreated(address token, uint256 classId, string symbol);

    event voteClassUpdated(uint128 newClass, uint256 quorum);

    event teamAllocChanged(address to, uint256 newDBITPPM, uint256 newDGOVPPM);

    event tokenMigrated(address token, address from, address to, uint256 amount);

    event communityFundChanged(uint256 newDBITBudget, uint256 newDGOVBudget);

    event executableContractUpdated(address executableAddress);
    
    event bankContractUpdated(address bankAddress);

    event exchangeContractUpdated(address exchangeAddress);
    
    event bondManagerContractUpdated(address bankBondManagerAddress);

    event oracleContractUpdated(address oracleAddress);

    event airdropContractUpdated(address airdropAddress);

    event governanceContractUpdated(address governanceAddress);

}
