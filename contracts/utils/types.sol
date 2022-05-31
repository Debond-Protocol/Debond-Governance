pragma solidity ^0.8.10;


library types {

enum ProposalApproval {Both, ShouldApprove, CanVeto}
enum ProposalStatus {Approved, Paused, Revoked, Ended}
enum VoteChoice {For, Against, Abstain}




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







}