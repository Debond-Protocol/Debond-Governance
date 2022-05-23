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
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./utils/GovernanceOwnable.sol";
import "./interfaces/IGovStorage.sol";
import "./interfaces/IGovernance.sol";
contract GovStorage is AccessControl, GovernanceOwnable , IGovStorage {

    // TODO: only governance will have  the R/W but others can Read only.
    constructor(address _governanceAddress) {
      //  getRole(DEFAULT_ADMIN_ROLE, governanceAddress);

      governance = _governanceAddress;
    }
    struct Proposal {
        address owner;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 numberOfVoters;
        uint256 minimumNumberOfVotes;
        uint256 dbitRewards;
        uint256 executionNonce;
        uint256 executionInterval;
        address contractAddress;
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

    struct ProposalClassInfo {
        uint128[] nonces;
        uint256 timelock;
        uint256 minimumApproval;
        uint256 minimumVote;
        uint256 architectVeto;
        uint256 maximumExecutionTime;
        uint256 minimumExecutionInterval;
    }

    struct AllocatedToken {
        uint256 allocatedDBITMinted;
        uint256 allocatedDGOVMinted;
        uint256 dbitAllocationPPM;
        uint256 dgovAllocationPPM;
    }

    address public debondOperator;  // entities with Veto access for the proposal
    address public debondTeam;
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

    uint256 public dbitBudgetPPM;
    uint256 public dgovBudgetPPM;
    uint256 public dbitAllocationDistibutedPPM;
    uint256 public dgovAllocationDistibutedPPM;
    uint256 public dbitTotalAllocationDistributed;
    uint256 public dgovTotalAllocationDistributed;

    mapping(bytes32 => Vote) votes;
    mapping(uint128 => ProposalClass) proposalClass;
    mapping(address => AllocatedToken) allocatedToken;
    mapping(address => uint256) internal voteTokenBalance;
    mapping(uint128 => mapping(uint128 => Proposal)) proposal;
    mapping(uint128 => ProposalClassInfo) proposalClassInfo;

    enum ProposalStatus {Approved, Paused, Revoked, Ended}
    enum VoteChoice {For, Against, Abstain}
    enum ProposalApproval { Both, ShouldApprove, CanVeto}

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


    /**its used for setting  new governance contract  ,  */
    function setCurrentGovernance(address newGovernanceAddress,  uint proposalId , uint _proposalClass) hasRole(DEFAULT_ADMIN_ROLE, msg.sender) returns(bool) {
    //    setGovernanceAddress(newGovernanceAddress);
    require(this.getProposalDetails(proposalId , _proposalClass).status  == ProposalStatus.Approved, "setGovernance:accessDenied");

    governance = newGovernanceAddress;

    }
    function getProposalDetails(
            uint128 _class,
            uint128 _nonce
        ) external view returns(Proposal memory _proposal) {
            _proposal = proposal[_class][_nonce];
    }


    function  setProposalStatus(uint128 _class , uint128 _nonce, ProposalStatus newStatus) external {
                require(msg.sender == governance, " current governance can access");
    proposal[_class][_nonce].status = ProposalStatus.newStatus;
    } 



   
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
    ) external onlyApprovedGovernance {
        require(msg.sender == governance, " current governance can access");
        require(Address.isContract(_contractAddress), "Gov: Proposal contract not valid");

        uint128 _nonce = _generateNewNonce(_class);

        proposal[_class][_nonce].owner = _owner;
        proposal[_class][_nonce].startTime = block.timestamp;
        require(block.timestamp < _endTime, "Gov: incorrect end time");
        proposal[_class][_nonce].endTime = _endTime;
        proposal[_class][_nonce].dbitRewards = _dbitRewards;
        proposal[_class][_nonce].contractAddress = _contractAddress;
        proposal[_class][_nonce].approvalMode = _approvalMode;
        proposal[_class][_nonce].proposalHash = _proposalHash;
        proposal[_class][_nonce].executionNonce = _executionNonce;
        proposal[_class][_nonce].executionInterval = _executionInterval;
        proposal[_class][_nonce].status = ProposalStatus.Approved;
        proposal[_class][_nonce].dbitDistributedPerDay = _dbitDistributedPerDay;


    }

    /**
     */
    function setAllocatedToken(address _for , uint _allocatedDGOVMinted , uint _allocatedDBITMinted , uint _dbitAllocationPPM , uint _dgovAllocationPPM ) external {
        require(msg.sender == governance, " current governance can access");
        allocatedToken[_for].allocatedDGOVMinted = _allocatedDGOVMinted; 
        allocatedToken[_for].allocatedDBITMinted = _allocatedDBITMinted;
        allocatedToken[_for].dbitAllocationPPM = _dbitAllocationPPM;
        allocatedToken[_for].dgovAllocationPPM = _dgovAllocationPPM;
    }


    




}
