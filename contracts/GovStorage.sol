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

contract GovStorage {
    struct Proposal {
        address owner;
        address contractAddress;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 numberOfVoters;
        uint256 minimumNumberOfVotes;
        uint256 dbitRewards;
        uint256[] dbitDistributedPerDay;
        uint256[] totalVoteTokensPerDay;
        ProposalApproval approvalMode;
        bytes32 proposalHash;
        ProposalStatus status;
    }

    struct Vote {
        uint128 class;
        uint128 nonce;
        address contractAddress;
        bool voted;
        VoteChoice vote;
        uint256 amountTokens;
        uint256 votingDay;
    }

    struct ProposalClass {
        uint128 nonce;
    }

    struct AllocatedToken {
        uint256 allocatedDGOVMinted;
        uint256 allocatedDBITMinted;
        uint256 dbitAllocationPPM;
        uint256 dgovAllocationPPM;
    }

    address public debondOperator;  // entities with Veto access for the proposal
    address public DBIT;
    address public dGoV;
    address public bank;
    address public voteToken;
    address public governance;
    address public stakingContract;

    uint256 public _totalVoteTokenSupply;
    uint256 public _totalVoteTokenMinted;
    uint256 public _dbitAmountForOneVote;

    uint256 constant public NUMBER_OF_SECONDS_IN_DAY = 1 days;
    uint256 private stakingDgoVDuration;
    uint256 private _lockTime;

    uint256 public dbitTotalAllocationDistributed = 85e3;
    uint256 public dgovTotalAllocationDistributed = 8e4;

    mapping(bytes32 => Vote) votes;
    mapping(uint128 => ProposalClass) proposalClass;
    mapping(address => AllocatedToken) allocatedToken;
    mapping(address => uint256) internal voteTokenBalance;
    mapping(uint128 => mapping(uint128 => Proposal)) proposal;

    enum ProposalStatus {Approved, Paused, Revoked, Ended}
    enum ProposalApproval {Both, ShouldApprove, CanVeto}
    enum VoteChoice {For, Against, Abstain}

    modifier onlyGov {
        require(msg.sender == governance, "Gov: not governance");
        _;
    }

    modifier onlyDebondOperator {
        require(msg.sender == debondOperator, "Gov: Need rights");
        _;
    }

    modifier canClaimTokens(uint128 _class, uint128 _nonce) {
        Proposal memory _proposal = proposal[_class][_nonce];
        require(_proposal.endTime + _lockTime <= block.timestamp, "");
        _;
    }

    modifier onlyActiveProposal(uint128 _class, uint128 _nonce) {
        Proposal memory _proposal = proposal[_class][_nonce];
        require(
            _proposal.endTime >= block.timestamp,
            "Gov: proposal not found"
        );
        require(_proposal.status == ProposalStatus.Approved);
        _;
    }

    modifier onlyActiveOrPausedProposal(uint128 _class, uint128 _nonce) {
        Proposal memory _proposal = proposal[_class][_nonce];
        require(
            (
                _proposal.endTime >= block.timestamp &&
                _proposal.status == ProposalStatus.Approved
            ) || _proposal.status == ProposalStatus.Paused,
            "Gov: not active or paused"
        );
        _;
    }

    modifier onlyPausedProposal(uint128 _class, uint128 _nonce) {
        Proposal memory _proposal = proposal[_class][_nonce];
        require(
            _proposal.status == ProposalStatus.Paused,
            "Gov: proposal not paused"
        );
        _;
    }

    modifier onlyCorrectOwner(bytes32 proposalHash,uint128 classId, uint128 proposalId) {
        require(proposalHash == proposal[classId][proposalId].proposalHash, "proposal executed is not mentioned corresponding to proposal");
        _;
    }  
}
