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
import "Debond-ERC3475/contracts/interfaces/IDebondBond.sol";

contract GovStorage is AccessControl, GovernanceOwnable, IGovStorage {
    // system total allocation variables:
    uint256  public dbitTotalAllocationDistributed;
    uint256 public dgovTotalAllocationDistributed;
    uint256 public dbitBudgetPPM;
    uint256 public dgovBudgetPPM;
    uint256 public dbitAllocationDistibutedPPM;
    uint256 public dgovAllocationDistibutedPPM;

    // bank constants.
    uint public benchmarkInterestRate;


    modifier onlyGov() {
        require(msg.sender == governance, "only governance contract can call");
        _;
    }

    modifier onlyVoteHolders() {
        require(
            IERC20(voteToken).balanceOf(msg.sender) > 0,
            "only vote holders can create proposal"
        );
        _;
    }

    // TODO: only governance address will be of the governance ownable.
    constructor( address _governanceAddress) GovernanceOwnable(_governanceAddress) {
        //  getRole(DEFAULT_ADMIN_ROLE, governanceAddress);
        governanceAddress = _governanceAddress;
    }

    address public debondOperator; // entities with Veto access for the proposal
    address public debondTeam;
    address public DBIT;
    address public dGoV;
    address public bank;
    address public governance;
    address public stakingContract;

    uint256 public _totalVoteTokenSupply;
    uint256 public _totalVoteTokenMinted;
    uint256 public _dbitAmountForOneVote;

    uint256 public constant NUMBER_OF_SECONDS_IN_DAY = 1 days;
    uint256 private stakingDgoVDuration;
    uint256 private _lockTime;

   

    
    mapping(bytes32 => Vote) votes;
    mapping(uint256 => ProposalClass) proposalClass;
    mapping(address => AllocatedToken) private allocatedToken;
    mapping(address => uint256) internal voteTokenBalance;
    mapping(uint256 => mapping(uint256 => Proposal)) proposal;
    mapping(uint256 => ProposalClassInfo) proposalClassInfo;

    function getProposal(uint256 _class, uint256 _nonce)
        public
        view
        returns (Proposal memory _proposal)
    {
        _proposal = proposal[_class][_nonce];
    }

    function getVoteDetails(bytes32 hash)
        public
        override
        view
        returns (Vote memory details)
    {
        details = votes[hash];
    }

    function getProposalClassInfo(uint256 _class)
        external
        override
        view
        returns (ProposalClassInfo memory _proposalClassInfo)
    {
        _proposalClassInfo = proposalClassInfo[_class];
    }


    function getDebondOperator() external returns(address) {return debondOperator;}

    function getTokenAllocation(address _of)
        public
        view 
        override
        returns (AllocatedToken memory _allocatedToken)

    {
        _allocatedToken = allocatedToken[_of];

    }

    

    function setProposalStatus(
        uint256 _class,
        uint256 _nonce,
        IGovStorage.ProposalStatus newStatus
    ) external onlyGov {
        require(msg.sender == governance, " current governance can access");
        proposal[_class][_nonce].status = newStatus;
    }

    function setProposalClassStatus(
        uint256 _class,
        bool status
    )
    public 
    onlyGov
    {
        proposalClass[_class].exist = status;
 
    }


    function getClassNonceInfo(uint256 _class) public  view   returns(uint256) {
return proposalClass[_class].nonce;    
    }


    function setProposalVote(
        uint256 _class,
        uint256 _nonce,
        uint256 _amount,
        IGovStorage.VoteChoice choice,
        bytes32 hash,
        uint256 forVotes,
        uint256 againstVotes
    ) public onlyGov {
        if (choice == VoteChoice.For) {
            proposal[_class][_nonce].forVotes = forVotes + _amount;
            votes[hash].vote = choice;
        } else if (choice == VoteChoice.Against) {
            proposal[_class][_nonce].againstVotes = againstVotes + _amount;
            votes[hash].vote = choice;
        }
    }



    function setProposalExecutionInterval(
        uint256 _class,
        uint256 _nonce,
        uint newinterval
    )
    external
    override
    onlyGov
    returns(bool)
    {
        proposal[_class][_nonce].executionInterval = newinterval;
        return(true);
    }


    function registerProposal(
        uint256 _class,
        address _owner,
        uint256 _endTime,
        uint256 _dbitRewards,
        address _contractAddress,
        bytes32 _proposalHash,
        uint256 _executionNonce,
        uint256 _executionInterval,
        IGovStorage.ProposalApproval _approvalMode,
        uint256[] memory _dbitDistributedPerDay
    ) external onlyVoteHolders override {
        require(msg.sender == governance, " current governance can access");
        require(
            Address.isContract(_contractAddress),
            "Gov: Proposal contract not valid"
        );

        uint256 _nonce = _generateNewNonce(_class);

        proposal[_class][_nonce].owner = _owner;
        proposal[_class][_nonce].startTime = block.timestamp;
        require(block.timestamp < _endTime, "Gov: incorrect end time");
        proposal[_class][_nonce].endTime = _endTime;
        proposal[_class][_nonce].dbitRewards = _dbitRewards;
        proposal[_class][_nonce].contractAddress = _contractAddress;
       // TODO: check that whether its set to be same as that of the proposal class info.
       // require(this.getProposalClassInfo(_class).architectVeto == _approvalMode., "not  same  approval method  than class");
        proposal[_class][_nonce].approvalMode = _approvalMode;
        proposal[_class][_nonce].proposalHash = _proposalHash;
        proposal[_class][_nonce].executionNonce = _executionNonce;
        proposal[_class][_nonce].executionInterval = _executionInterval;
        proposal[_class][_nonce].status = ProposalStatus.Approved;
        proposal[_class][_nonce].dbitDistributedPerDay = _dbitDistributedPerDay;
    }
    /**
    register proposal class inforamtion (for the first time).
    @dev to be called only one time in ogvernance constructor for defining the parameters for the given class 
    TODO: determine whether people can change the parameters .
    _nonce cant be changed.
     */
    function registerProposalClassInfo(
        uint256 _class,
        uint256 _timelock,
        uint256 _minimumApproval,
        uint256 _minimumVote,
        bool _architectVeto,
        uint256 _maximumExecutionTime,
        uint256 _minimumExecutionInterval
    ) external onlyGov {
        proposalClass[_class].exist = true; 
        proposalClassInfo[_class].timelock = _timelock;
        proposalClassInfo[_class].minimumApproval = _minimumApproval;
        proposalClassInfo[_class].minimumVote = _minimumVote;
        proposalClassInfo[_class].architectVeto = _architectVeto;
        proposalClassInfo[_class].maximumExecutionTime = _maximumExecutionTime;
        proposalClassInfo[_class].minimumExecutionInterval = _minimumExecutionInterval;
        
    }

    /**
    for calling  called in governance.vote() function to register vote.
    @dev to be only called by governance contract.
     */
    function registerVote(
        bytes32 voteHash,
        uint256 _class,
        uint256 _nonce,
        address _contractAddress,
        uint256 amountTokens,
        uint256 votingDay
    ) external  onlyGov override {
        votes[voteHash].class = _class;
        votes[voteHash].nonce = _nonce;
        votes[voteHash].contractAddress = _contractAddress;
        votes[voteHash].voted = true;
        votes[voteHash].amountTokens = amountTokens;
        votes[voteHash].votingDay = votingDay;
    }

    /**

     */
    function setAllocatedTokenPPM(
        address _for,
        uint256 _dbitAllocationPPM,
        uint256 _dgovAllocationPPM
    ) external onlyGov {
        allocatedToken[_for].dbitAllocationPPM = _dbitAllocationPPM;
        allocatedToken[_for].dgovAllocationPPM = _dgovAllocationPPM;
    }


    function setTotalAllocationDistributed(
        uint256 _dbitTotalAllocationDistributed,
        uint256 _dgovTotalAllocationDistributed
    ) external onlyGov {
        dbitTotalAllocationDistributed = _dbitTotalAllocationDistributed;
        dgovTotalAllocationDistributed = _dgovTotalAllocationDistributed;
    }


    function getAllocatedTokenPPM(
        address _for
    ) external returns(uint dbitAlloc,uint  dgovAlloc) {
        dbitAlloc = allocatedToken[_for].dbitAllocationPPM;
        dgovAlloc = allocatedToken[_for].dgovAllocationPPM;
    }

    function getAllocatedToken(
        address _of
    ) external returns(AllocatedToken memory _allocatedToken) {
        return allocatedToken[_of];
    }

    function getTotalAllocatedDistributedPPM() external view override returns (uint dbitTotal , uint dgovTotal) {
            dbitTotal = dbitAllocationDistibutedPPM;
            dgovTotal = dgovAllocationDistibutedPPM;    
    }


    function setTotalAllocationDistributedPPM(uint dbitAlloc , uint dgovAlloc)  onlyGov  external 
    {   dbitAllocationDistibutedPPM = dbitAlloc;
        dgovAllocationDistibutedPPM = dgovAlloc;

        
    }


    function  getTotalAllocatedDistributed() external returns(uint dbitTotal, uint dgovTotal ) {
        dbitTotal = dbitTotalAllocationDistributed;
        dgovTotal = dgovTotalAllocationDistributed;
    }





    function setBudgetDBITPPM(uint256 _newBudget) external  onlyGov{
        dbitBudgetPPM = _newBudget;
    }

    function setBudgetDGOVPPM(uint256 _newBudget) external  onlyGov{
        dgovBudgetPPM = _newBudget;
    }

    function getBudgetPPM() external returns(uint dbit , uint dgov) {
        dbit = dbitBudgetPPM;
        dgov = dgovBudgetPPM;
    }

    function addAllocatedDGOVMinted( address _to ,uint256 _amountDBIT, uint256 _amountDGOV ) external  onlyGov {
    allocatedToken[_to].allocatedDBITMinted += _amountDBIT;
    allocatedToken[_to].allocatedDGOVMinted += _amountDGOV;

    dbitTotalAllocationDistributed += _amountDBIT;
    dgovTotalAllocationDistributed += _amountDGOV;
     }
     
     function addAllocatedTokenMinted(address _to ,uint256 _amountDBIT, uint256 _amountDGOV)  external onlyGov {
         allocatedToken[_to].allocatedDBITMinted += _amountDBIT;
         allocatedToken[_to].allocatedDGOVMinted += _amountDGOV;
     }


    

    function setAmountsToken(bytes32 hash, uint value) onlyGov override external
    {
        votes[hash].amountTokens = value;

    }
  
    /**
    @dev defines the totalVoteTokens reimbursed for the interest.
    
    
     */
    function setTotalVoteTokensPerDay(uint256 _class , uint256 _nonce , uint day, uint totalVoteTokensPerDay ,uint _amountVoteTokens) onlyGov external 
    {
        proposal[_class][_nonce].totalVoteTokensPerDay[day] = totalVoteTokensPerDay + _amountVoteTokens;

    }
    /**
     * @dev generate a new nonce for a given class
     * @param _class proposal class
     * @return nonce  generating new nonce.
     */
    function _generateNewNonce(uint256 _class)
        internal
        returns (uint256 nonce)
    {
        proposalClass[_class].nonce++;
        nonce = proposalClass[_class].nonce;
    }


    function setBenchmarkInterestRate(uint _newInterestRate) external onlyGov  {
        benchmarkInterestRate = _newInterestRate;


    }




}
