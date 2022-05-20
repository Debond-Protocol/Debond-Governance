pragma solidity ^0.8.9;



  enum ProposalApproval {Both, ShouldApprove, CanVeto}
   enum ProposalStatus {Approved, Paused, Revoked, Ended}


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


interface IGovStorage {




function getProposal(
            uint128 _class,
            uint128 _nonce
        ) external view returns(Proposal memory _proposal) ;


 /**
    * @dev registers a proposal in the database (from the approved governance contract).
    * @param _class proposal class
    * @param _endTime prosal end time
    * @param _contractAddress the proposal contract address
    */


function registerProposal(uint proposalId) external view returns ;
/**

@dev  set the governance contract
@param   newGovernanceAddress to be set governance address.
@param proposa
 */



function setCurrentGovernance(address newGovernanceAddress,  uint proposalClass, uint proposalNonce) hasRole(DEFAULT_ADMIN_ROLE, msg.sender) returns(bool);



function addAllocationMember(address _to , uint256 _amount, uint proposal_class, uint proposal_nonce) external;

function mintGOVAllocation(address _to , uint256 _amount, uint proposal_class, uint proposal_nonce ) external;

function mintDBITAllocation(address _to , uint256 _amount, uint proposal_class, uint proposal_nonce ) external;






}