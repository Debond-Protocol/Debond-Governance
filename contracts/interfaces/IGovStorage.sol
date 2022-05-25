//
pragma solidity ^0.8.9;

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
        IGovStorage.VoteChoice vote;
        uint256 amountTokens;
        uint256 votingDay;
    }



interface IGovStorage {
 
enum ProposalApproval {Both, ShouldApprove, CanVeto}
enum ProposalStatus {Approved, Paused, Revoked, Ended}
enum VoteChoice {For, Against, Abstain}

        

function getProposalDetails(
            uint128 _class,
            uint128 _nonce
        ) external  view
        returns(Proposal memory _proposal) ;


function getVoteDetails(bytes32 hash) external view returns(Vote calldata details);



 /** 
    * @dev registers a proposal in the database (from the approved governance contract).
    * @param _class proposal class
    * @param _endTime prosal end time
    * @param _contractAddress the proposal contract address
    */


function registerProposal(
        uint128 _class,
        address _owner, 
        uint256 _endTime,
        uint256 _dbitRewards,
        address _contractAddress,
        bytes32 _proposalHash,
        uint256 _executionNonce,
        uint256 _executionInterval,
        ProposalApproval _approvalMode,
        uint256[] memory _dbitDistributedPerDay
    ) external;



function setAllocatedTokenPPM(address _for ,  uint _dbitAllocationPPM , uint _dgovAllocationPPM ) external ;


function setTotalAllocationDistributed(uint dbitTotalAllocationDistributed , uint dgovTotalAllocationDistributed) external; 


function setProposalVote(uint128 _class , uint128 _nonce , uint _amount , IGovStorage.VoteChoice  choice,  bytes32 hash, uint forVotes,  uint againstVotes ) external  ;


function setUserVoted(uint128 _class , uint128 _nonce , uint nbOfVoters) external;

function _registerVote(
        bytes32 voteHash, 
        uint128 _class,
        uint128 _nonce,
        address _contractAddress,
        bool voted,
        uint _amount,
        uint amountTokens, 
        uint votingDay 
    ) external  returns (bool _voted);

}