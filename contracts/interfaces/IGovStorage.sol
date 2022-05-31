//MIT
pragma solidity ^0.8.9;

//import  "../utils/types.sol";

interface IGovStorage {
 // state for Proposal to be approved.
    enum ProposalApproval {
        Both,
        ShouldApprove,
        CanVeto
    }
    enum ProposalStatus {
        Approved,
        Paused,
        Revoked,
        Ended,
        Active
    }
    enum VoteChoice {
        For,
        Against,
        Abstain
    }


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
        uint256 executionNonce;
        uint256 executionInterval;
        uint256[] dbitDistributedPerDay;
        uint256[] totalVoteTokensPerDay;
        ProposalApproval approvalMode;
        bytes32 proposalHash;
        ProposalStatus status;
    }

    struct Vote {
        uint256 class;
        uint256 nonce;
        address contractAddress;
        bool voted;
        VoteChoice vote;
        uint256 amountTokens;
        uint256 votingDay;
    }



     struct ProposalClass {
        uint256 nonce;
        bool  exist;
    }

    struct ProposalClassInfo {
        uint256[] nonces;
        uint256 timelock;
        uint256 minimumApproval;
        uint256 minimumVote;
        //uint256 architectVeto; 
        bool  architectVeto; // defines whether all of the proposals need the architectVeto or not .
        uint256 maximumExecutionTime;
        uint256 minimumExecutionInterval;
    }

    struct AllocatedToken {
        uint256 allocatedDBITMinted;
        uint256 allocatedDGOVMinted;
        uint256 dbitAllocationPPM;
        uint256 dgovAllocationPPM;
    }



/** getting proposal details 
    _class the proposal class which you want to check.
    _nonce is the proposalID / nonce to the given class that you want to check.
    returns the proposal object  structure if therre is one.
 */
    function getProposal(uint256 _class, uint256 _nonce)
        external
        view
        returns (Proposal memory _proposal);
// 
    function getVoteDetails(bytes32 hash)
        external
        view
        returns (Vote calldata details);


    function getProposalClassInfo(uint256 _class)
        external
        view
    returns (ProposalClassInfo memory _proposalClassInfo);



     function getTokenAllocation(address _of)
        external
        view 
        returns (AllocatedToken memory _allocatedToken);

    function getTotalAllocatedDistributed() external  returns (uint dbitTotal , uint dgovTotal);


    function getBudgetPPM() external returns(uint dbit , uint dgov);

    /**
     * @dev registers a proposal in the database (from the approved governance contract).
     * @param _class proposal class
     * @param _endTime prosal end time
     * @param _contractAddress the proposal contract address
     */

    function registerProposal(
        uint256 _class,
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


    function registerProposalClassInfo(
        uint256 _class,
        uint256 _timelock,
        uint256 _minimumApproval,
        uint256 _minimumVote,
        bool _architectVeto,
        uint256 _maximumExecutionTime,
        uint256 _minimumExecutionInterval
    ) external;

    function setAllocatedTokenPPM(
        address _for,
        uint256 _dbitAllocationPPM,
        uint256 _dgovAllocationPPM
    ) external;

    function setTotalAllocationDistributed(
        uint256 dbitTotalAllocationDistributed,
        uint256 dgovTotalAllocationDistributed
    ) external;

    function setBudgetDBITPPM(uint256 _newBudget) external;


    function setBudgetDGOVPPM(uint256 _newBudget) external;

    function setProposalVote(
        uint256 _class,
        uint256 _nonce,
        uint256 _amount,
        IGovStorage.VoteChoice choice,
        bytes32 hash,
        uint256 forVotes,
        uint256 againstVotes
    ) external;

    function setProposalExecutionInterval(
        uint256 _class,
        uint256 _nonce,
        uint newinterval
    )
    external
    returns(bool);



     function registerVote(
        bytes32 voteHash,
        uint256 _class,
        uint256 _nonce,
        address _contractAddress,
        uint256 amountTokens,
        uint256 votingDay
    ) external ;


    function getDebondOperator() external returns(address);
   
    function getClassNonceInfo(uint256 _class) external  view  returns(uint256);


    function setProposalStatus(
        uint256 _class,
        uint256 _nonce,
        ProposalStatus newStatus
    ) external;

    /**
    function to set the current supply og minted DBIT / DGOV for the minting after minting the allocation.
     */

    function addAllocatedTokenMinted( address _to ,uint256 _amountDBIT, uint256 _amountDGOV ) external ;





    /** getting the detailsof the allocatedToken.
    * 
     */

    function getAllocatedToken(
        address _of
    ) external returns(AllocatedToken memory _allocatedToken);



    function setTotalVoteTokensPerDay(uint256 _class , uint256 _nonce , uint day, uint totalVoteTokensPerDay ,uint _amountVoteTokens)  external ;



    function getTotalAllocatedDistributedPPM() external view  returns (uint dbitTotal , uint dgovTotal);


    function setTotalAllocationDistributedPPM(uint dbitAlloc , uint dgovAlloc)   external ;



    /**
    setting the amtTokens for the vote (in order to burn the vote tokens when burning ).
    * @param  hash is the hash of the vote generated  for given user .
    * @param value is the amount of vote tokens that are needed to be removed
    */
    function setAmountsToken(bytes32 hash, uint value)  external;



    function getAllocatedTokenPPM(
        address _for
    ) external returns(uint dbitAlloc,uint  dgovAlloc);

}
