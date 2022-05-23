pragma solidity ^0.8.9;

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
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract GovStorage is AccessControl, GovernanceOwnable , IGovStorage {


    // system total allocation variables: 
    uint dbitTotalAllocationDistributed;
    uint dgovTotalAllocationDistributed;



    // enums .




    modifier onlyGov() {
        require(msg.sender == governance,"only governance contract can call");
        _;
    }

    modifier onlyVoteHolders() {
        require(IERC20(voteToken).balanceOf(msg.sender) > 0 , "only vote holders can create proposal");
        _;
    } 



    // TODO: only governance will have  the R/W but others can Read only.
    constructor(address _governanceAddress, address _debondOperator) {
      //  getRole(DEFAULT_ADMIN_ROLE, governanceAddress);

      governance = _governanceAddress;
      debondOperator  = _debondOperator;

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
        IGovStorage.ProposalApproval approvalMode;
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

    mapping(bytes32 => Vote) votes;
    mapping(uint128 => ProposalClass) proposalClass;
    mapping(address => AllocatedToken) allocatedToken;
    mapping(address => uint256) internal voteTokenBalance;
    mapping(uint128 => mapping(uint128 => Proposal)) proposal;
    mapping(uint128 => ProposalClassInfo) proposalClassInfo;
    
   


    /**its used for setting  new governance contract  TODO: from the governanceOwnable  */
    // function setCurrentGovernance(address newGovernanceAddress,  uint proposalId , uint _proposalClass) hasRole(DEFAULT_ADMIN_ROLE, msg.sender) public returns(bool) {
    // //    setGovernanceAddress(newGovernanceAddress);
    // require(this.getProposalDetails(proposalId , _proposalClass).status  == ProposalStatus.Approved, "setGovernance:accessDenied");

    // governance = newGovernanceAddress;

    // }
    
function getProposalDetails(
            uint128 _class,
            uint128 _nonce
        ) external view  
        returns(Proposal memory _proposal)  {
            _proposal = proposal[_class][_nonce];
    }

    function getProposalClassInfo(
        uint128 _class
    ) external view returns(ProposalClassInfo memory _proposalClassInfo) {
        _proposalClassInfo = proposalClassInfo[_class];

    }

    function  setProposalStatus(uint128 _class , uint128 _nonce, ProposalStatus newStatus) external {
                require(msg.sender == governance, " current governance can access");
    proposal[_class][_nonce].status = newStatus;
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
        IGovStorage.ProposalApproval _approvalMode,
        uint256[] memory _dbitDistributedPerDay
    ) external override   {
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
    register proposal class inforamtion 
    @dev to be called only one time in ogvernance constructor for defining the parameters for the given class 
    TODO: determine whether people can change the parameters .
    _nonce cant be changed.

     */

    function registerProposalClassInfo(
        uint128 _class,
        uint256 _timelock,
        uint256 _minimumApproval,
        uint256 _minimumVote,
        uint256 _architectVeto,
        uint256 _maximumExecutionTime,
        uint256 _minimumExecutionInterval
    ) external  onlyGov {
     proposalClassInfo [_class].timelock =   _timelock;
     proposalClassInfo [_class].minimumApproval = _minimumApproval;
     proposalClassInfo [_class].minimumVote = _minimumVote;
     proposalClassInfo [_class].architectVeto = _architectVeto;
     proposalClassInfo[_class].maximumExecutionTime = _maximumExecutionTime;
     proposalClassInfo[_class].minimumExecutionInterval = _minimumExecutionInterval;
    }

    /**
     */
    function setAllocatedTokenPPM(address _for  , uint _dbitAllocationPPM , uint _dgovAllocationPPM ) external onlyGov {
        
        allocatedToken[_for].dbitAllocationPPM = _dbitAllocationPPM;
        allocatedToken[_for].dgovAllocationPPM = _dgovAllocationPPM;
    }


    function setTotalAllocationDistributed(uint _dbitTotalAllocationDistributed , uint _dgovTotalAllocationDistributed) external onlyGov {
    dbitTotalAllocationDistributed = _dbitTotalAllocationDistributed;
    dgovTotalAllocationDistributed = _dgovTotalAllocationDistributed;

    }
      /**
    * @dev generate a new nonce for a given class
    * @param _class proposal class
    * @return nonce  generating new nonce.
    */
    function _generateNewNonce(uint128 _class) internal returns(uint128 nonce) {
        proposalClass[_class].nonce++;
        nonce = proposalClass[_class].nonce;
    }





}
