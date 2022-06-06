pragma solidity ^0.8.9;

// SPDX-License-Identifier: apache 2.0
/*
    Copyright 2020 Sigmoid Foundation <info@dGOV.finance>
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
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./GovStorage.sol";
import "./interfaces/IVoteToken.sol";
import "./interfaces/IGovStorage.sol";
import "./interfaces/IStakingDGOV.sol";
import "./interfaces/IGovernance.sol";
import "./Pausable.sol";
import "./interfaces/IGovStorage.sol";
import "debond-token/contracts/interfaces/IdGOV.sol";

import "debond-token/contracts/interfaces/IDebondToken.sol";
//import "Debond-Exchange/contracts/interfaces/IExchange.sol";
import "debond-bank/contracts/interfaces/IData.sol";
//import "Debond-ERC3475/contracts/interfaces/IDebondBond.sol";



import "./utils/GovernanceOwnable.sol";




contract Governance is  IGovernance, ReentrancyGuard, Pausable , GovernanceOwnable  {

    string public  constant name  = "D/BOND Governance contract"; 

    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    uint256 public constant NUMBER_OF_SECONDS_IN_DAY = 1 days;

    // only used for data type reference in getProposal
     struct ProposalClassInfo {
        uint128[] nonces;
        uint256 timelock;
        uint256 minimumApproval;
        uint256 minimumVote;
        uint256 architectVeto;
        uint256 maximumExecutionTime;
        uint256 minimumExecutionInterval;
    }
    //  for govStorage access.
    IGovStorage govStorage;
    IData data;
    IdGOV Dgov;
    
    // address  of DBIT.
    address  dbitAddr;
    address dGOV;
    address vote;
    address debondOperator; 
    address debondTeam; // this is the treasury for the debondTeam for paying the allcoation 
    address stakingContract;
    // defines the maximum time BUDGET for PPM  for sharing.
    uint public dbitBudgetPPM;
    uint public dgovBudgetPPM;

    event ProposalApprovalStatus(uint _class , uint nonce , IGovStorage.ProposalStatus Status);

    //modifier 

     modifier onlyDebondOperator {
        require(msg.sender == debondOperator, "Gov: not governance");
        _;
    }

    modifier onlyActiveProposal(uint128 _class, uint128  _nonce) {
        require(govStorage.getProposal(_class, _nonce).status == IGovStorage.ProposalStatus.Active, "NOT ACTIVE");
        _;
    }

    modifier onlyPausedProposal(uint128 _class, uint128 _nonce) {
    require(govStorage.getProposal(_class, _nonce).status == IGovStorage.ProposalStatus.Active, "NOT ACTIVE");
    _;
    }

    constructor(
        address _dbit,
        address _dGoV,
        address _stakingContract,
        address _voteToken,
        address _debondOperator,
        address _debondTeam,
        address _governanceStorage,
        address dataAddr,
        address _governanceOwnable
    ) GovernanceOwnable(_governanceOwnable)  {
        dbitAddr = _dbit;
        dGOV = _dGoV;
        vote = _voteToken;
        stakingContract = _stakingContract;
        debondOperator = _debondOperator;
        debondTeam = _debondTeam;
        govStorage = IGovStorage(_governanceStorage); 
        data = IData(dataAddr);
        Dgov = IdGOV(_dGoV);



        // with parameter dbitAllocationPPM and dgovAllocationPPM.
        govStorage.setAllocatedTokenPPM(debondTeam, 8e4 * 1 ether, 4e4 * 1 ether);
        uint dbitTotalAllocationDistributed = 85e3 * 1 ether;
        uint dgovTotalAllocationDistributed = 8e4 * 1 ether;
        govStorage.setTotalAllocationDistributed(dbitTotalAllocationDistributed,dgovTotalAllocationDistributed);
        
        dbitBudgetPPM = 1e5 * 1 ether;
        dgovBudgetPPM = 1e5 * 1 ether;




    // with parameters timelock, minimumApproval , _minimumVote , _architectVeto , _maximumExecutionTime , _minimumExecutionInterval.
    govStorage.registerProposalClassInfo(0,3,150,30,false,3,1);
    govStorage.registerProposalClassInfo(1,3,170,60,true,5,2);
    govStorage.registerProposalClassInfo(2,3,300,70,true,11,3);
     
    }

  
    /** 
    * @dev set the Debond operator contract address
    * @param _debondOperator new Debond operator address
    */
    function setDebondOperator(address _debondOperator) nonReentrant external {
        require(msg.sender == debondOperator, "only present owner can change the access ");
        require(_debondOperator != debondOperator, "Gov: same Gov. address");

        debondOperator = _debondOperator;
    }

 
    /** 
    * @dev creates a proposal
    * @param _class proposal class
    * @param _endTime prosal end time
    * @param _contractAddress the proposal contract address
    */
    function registerProposal(
        uint128 _class,
        uint128 _nonce,
        address _owner, 
        uint256 _endTime,
        uint256 _dbitRewards,
        address _contractAddress,
        bytes32 _proposalHash,
        uint256 _executionNonce,
        uint256 _executionInterval,
        IGovStorage.ProposalApproval _approvalMode,
        uint256[] memory _dbitDistributedPerDay
    ) external  {
       govStorage.registerProposal(_class,_owner,_endTime,_dbitRewards, _contractAddress, _proposalHash,_executionNonce , _executionInterval , _approvalMode,_dbitDistributedPerDay);
        _zeroArray(_class, _nonce, _dbitDistributedPerDay);
        emit proposalRegistered(_class, _nonce, _endTime, _contractAddress);
    }

    /** allows  anyone to pause the proposal (done by either the proposal owner or the  admin) 
    * @dev pause a active proposal
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function pauseProposal(
        uint128 _class,
        uint128 _nonce
    ) external onlyDebondOperator onlyActiveProposal(_class, _nonce) {
        require(msg.sender == govStorage.getProposal(_class,_nonce).owner || msg.sender == govStorage.getDebondOperator(), "only owner or the admin can pause proposal");
        govStorage.setProposalStatus(_class , _nonce , IGovStorage.ProposalStatus.Approved);
        emit proposalPaused(_class, _nonce);
    }

    /**
    * @dev unpause a active proposal (done by the operator ).
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function unpauseProposal(
        uint128 _class,
        uint128 _nonce
    ) external onlyDebondOperator onlyPausedProposal(_class, _nonce) {
       govStorage.getProposal(_class,_nonce).status = IGovStorage.ProposalStatus.Approved;
        emit proposalUnpaused(_class, _nonce);
    }
    /**
    
    * 
    */
    function approvalProposal(
        uint128 _class,
        uint128 _nonce,
        IGovStorage.ProposalStatus  Status // 
    ) external  onlyActiveProposal(_class, _nonce) onlyDebondOperator {
        // condition if the debondOperator  can veto , he can decide whether the contract are true or false. 
        if(govStorage.getProposal(_class, _nonce).approvalMode == IGovStorage.ProposalApproval.CanVeto)
{
        govStorage.setProposalStatus(_class,_nonce,Status);
        emit ProposalApprovalStatus(_class, _nonce, Status);
    
}
else if(govStorage.getProposal(_class, _nonce).approvalMode == IGovStorage.ProposalApproval.ShouldApprove)
{
    govStorage.setProposalStatus(_class,_nonce,IGovStorage.ProposalStatus.Approved);
        emit ProposalApprovalStatus(_class, _nonce, IGovStorage.ProposalStatus.Approved);
        emit proposalEnded(_class, _nonce);
}
  
    }
   
   

    /**
    * @dev  for allowing users use VOTE  tokens to given proposal.
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _userVote The voter vote: For or Against
    * @param _amountVoteTokens amount of vote tokens
    */
    function vote(
        address _voter,
        uint128 _class,
        uint128 _nonce,
        address _proposalContractAddress,
        IGovStorage.VoteChoice _userVote,
        uint256 _amountVoteTokens
    ) external onlyActiveProposal(_class, _nonce) nonReentrant() returns(bool voted) {
        // require the vote to be in progress
        IGovStorage.Proposal memory _proposal = govStorage.getProposal(_class,_nonce);

        require(block.timestamp < _proposal.endTime, "Gov: voting is over");
        
        // require the user has staked at least `_amountVoteTokens` dGoV tokens
        
        IStakingDGOV _stakingContract = IStakingDGOV(stakingContract);
        uint256 _amountStaked = _stakingContract.getStakedDGOV(_voter);
        require(_amountVoteTokens <= _amountStaked, "Gov: you need to stack dGoV tokens");
        
        // require the user has enough vote tokens
        IERC20 _voteTokenContract = IERC20(voteToken);
        require(
            _checkIfVoterHasEnoughVoteTokens(_voter, _amountVoteTokens),
            "Gov: not enough enough vote tokens"
        );

        // require the user hasn't voted yet
        require(_checkIfNotVoted(_class, _nonce, _proposalContractAddress), "Gov: Already voted");
        
        // LOCK THEM AND NOT TRANSFER
        _voteTokenContract.transferFrom(_voter, address(this), _amountVoteTokens);

        _vote(
            _class,
            _nonce,
            _amountVoteTokens,
            _proposalContractAddress,
            _userVote,
            _proposal
        );
                        
        voted = true;

        emit userVoted(_class, _nonce, _proposalContractAddress, _amountVoteTokens);
    }


    /**
    casting Voting by signature from the external signer (from compounds lab governorAlpha prootcol). 
    @param v is the function selection string generated by the 
    
     */


    function voteBySig(
        address _voter,
        uint128 _class,
        uint128 _nonce,
        address _proposalContractAddress,
        IGovStorage.VoteChoice _userVote,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) 
    {
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainId(), address(this)));
        bytes32 structhash = keccak256(abi.encode(BALLOT_TYPEHASH, _class, _nonce , _userVote));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);

        require(signatory != address(0), "invalid signature" );

         _vote(
            _class,
            _nonce,
            _amountVoteTokens,
            _proposalContractAddress,
            _userVote,
            _proposal
        );
        
        voted = true;

        emit userVotedBySig(_class, _nonce, _proposalContractAddress, _amountVoteTokens, signatory);


    }
   
  
    /**
    * @dev mint allocated DBIT to a given address (approved by whitelisting to core team)
    * @param _to the address to mint DBIT to
    * @param _amountDBIT the amount of DBIT to mint
    * @param _amountDGOV the amount of DGOV to mint
    */
    function mintAllocatedToken(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) public  onlyDebondOperator returns(bool) {
        IGovStorage.AllocatedToken memory _allocatedToken = govStorage.getTokenAllocation(_to);

        uint256 _dbitCollaterizedSupply = IDebondToken(dbitAddress).supplyCollateralised();
        uint256 _dgovCollaterizedSupply = Dgov.supplyCollateralised();

        require(
            IDebondToken(dbitAddress).allocatedSupplyBalance(_to) + _amountDBIT <=
            _dbitCollaterizedSupply * _allocatedToken.dbitAllocationPPM / 1 ether,
            "Gov: not enough supply of DBIT "
        );
        require(
            IdGOV(dGOV).allocatedSupplyBalance(_to) + _amountDGOV <=
            _dgovCollaterizedSupply * _allocatedToken.dgovAllocationPPM / 1 ether,
            "Gov: not enough supply"
        );

        IDebondToken(dbitAddress).mintAllocatedSupply(_to, _amountDBIT);

        IdGOV(dGOV).mintAllocatedSupply(_to, _amountDGOV);

        govStorage.addAllocatedTokenMinted(_to , _amountDBIT, _amountDGOV);

        return true;
    }


    /**
    * @dev check a proposal for approval voting percentage .
    */
    function checkProposal(
        uint128 _class,
        uint128 _nonce
    ) public view returns(bool) {
    IGovStorage.Proposal memory _proposal = govStorage.getProposal(_class,_nonce);
    IGovStorage.ProposalClassInfo memory _proposalClassInfo = govStorage.getProposalClassInfo(_class);
        uint256 timelock = _proposal.endTime - _proposal.startTime;

        require(
            _proposalClassInfo.timelock + timelock < block.timestamp,
            "Gov: wait"
        );

        uint256 approvalVotePercentage = (_proposal.forVotes * 1e6) / (_proposal.forVotes + _proposal.againstVotes);
        require(
            approvalVotePercentage >= _proposalClassInfo.minimumApproval,
            "Gov: minimum not reach"
        );
        bool veto ;
        if(_proposal.approvalMode == IGovStorage.ProposalApproval.CanVeto)
        {
            veto = true;

        }

        require(
            veto == _proposalClassInfo.architectVeto,
            "Gov: only architect role can approve the vote"
        );

        return true;
    }

    /**
    * @dev return a proposal
    * @param _class proposal class
    * @param _classInfo aclss info of class `_class`
    */
    function getClassInfo(
        uint128 _class
    ) external view returns(IGovStorage.ProposalClassInfo memory _classInfo) {
//        _classInfo = proposalClassInfo[_class];
        _classInfo = govStorage.getProposalClassInfo(_class);

    }

    /**
    * @dev gets the the chainID for the current EVM chain for signature generation.
    * 
    */

    function getChainId() internal pure returns (uint) {
        uint chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}


    /**
    * @dev return the array that contains number votes for each day
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function getNumberOfVotePerDay(
        uint128 _class,
        uint128 _nonce
    ) external view returns(uint256[] memory) {
        return govStorage.getProposal(_class,_nonce).totalVoteTokensPerDay;
    }

    /**
    * @dev update the proiposal and vote struct
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _amount amount of vote tokens
    * @param _contractAddress proposal contract address
    * @param _userVote The user vote: For or Against
    */
    function _vote(
        uint128 _class,
        uint128 _nonce,
        uint256 _amount,
        address _contractAddress,
        IGovStorage.VoteChoice _userVote,
        IGovStorage.Proposal memory _proposal
    ) internal {
        bytes32 hash = _hashVote(msg.sender, _class, _nonce, _contractAddress);

        // // these are total for votes 
        // // TODO:  we can also get the details  from govStorage.getProposal(_class,_nonce); 
         uint256 forVotes = govStorage.getProposal(_class,_nonce).forVotes;
         uint256 againstVotes = govStorage.getProposal(_class,_nonce).againstVotes;


        govStorage.setProposalVote(_class,_nonce,_amount, _userVote,  hash, forVotes, againstVotes);
        
        govStorage.getProposal(_class,_nonce).numberOfVoters += 1;
       
        _updateTotalVoteTokensPerDay(_class, _nonce, _amount);

        uint votingDay =  _getVotingDay(_class, _nonce);
     
        govStorage.registerVote(hash,_class,_nonce,_contractAddress,_amount,votingDay);

        govStorage.registerVote(
            hash,_class,_nonce,_contractAddress,_amount, votingDay
        );
    }


       /**
    * @dev returns a hash for  the vote
    * @param _voter the address of the voter
    * @param _class the proposal class
    * @param _nonce the proposal nonce
    * @param _contractAddress the proposal contract address
    */
    function _hashVote(
        address _voter,
        uint128 _class,
        uint128 _nonce,
        address _contractAddress
    ) private pure returns(bytes32 voteHash) {
        voteHash = keccak256(
            abi.encodePacked(
                _voter,
                _class,
                _nonce,
                _contractAddress
            )
        );
    }





    /**
    * @dev check if a user has enough vote tokens to vote
    * @param _voter the address of the voter
    * @param _amountVoteTokens amount ofg tokens to vote with
    * @param hasEnoughTokens true if the voter has enough vote tokens, false otherwise
    */
    function _checkIfVoterHasEnoughVoteTokens(
        address _voter,
        uint256 _amountVoteTokens
    ) internal view returns(bool hasEnoughTokens) {
        IERC20 _voteTokenContract = IERC20(voteToken);
        uint256 voteTokens = _voteTokenContract.balanceOf(_voter);

        hasEnoughTokens = _amountVoteTokens > 0 && _amountVoteTokens <= voteTokens;

        require(
            _amountVoteTokens > 0 &&
            _amountVoteTokens <= voteTokens,
            "Gov: not enough enough vote tokens"
        );
    }

    /**
    * @dev update the total vote tokens received for a proposal during 24 hours
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _amountVoteTokens amount of vote token to add
    */
    function _updateTotalVoteTokensPerDay(
        uint128 _class,
        uint128 _nonce,
        uint256 _amountVoteTokens
    ) internal {
        uint256 day = _getVotingDay(_class, _nonce);

        uint256 totalVoteTokensPerDay = govStorage.getProposal(_class,_nonce).totalVoteTokensPerDay[day];
       // govStorage.getProposal(_class,_nonce).totalVoteTokensPerDay[day] = totalVoteTokensPerDay + _amountVoteTokens;
        govStorage.setTotalVoteTokensPerDay(_class,_nonce,day,totalVoteTokensPerDay , _amountVoteTokens);




    }

    /**
    * @dev get the bnumber of days elapsed since the vote has started
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param day the current voting day
    */
    function _getVotingDay(uint128 _class, uint128 _nonce) internal view returns(uint256 day) {
        IGovStorage.Proposal memory _proposal = govStorage.getProposal(_class,_nonce);

        uint256 duration = _proposal.startTime > block.timestamp ?
            _proposal.startTime - block.timestamp:
            block.timestamp - _proposal.startTime;
        
        day = (duration / NUMBER_OF_SECONDS_IN_DAY);
    }



    /**
    * @dev Check if a user already voted for a proiposal
    * @param _hash vote hash
    * @param voted true if already voted, false if not
    */
    function _voted(bytes32 _hash) internal view returns(bool voted) {
        voted =   govStorage.getVoteDetails(_hash).voted;
    }

 

    /**
    * @dev check if a user hasn't voted yet
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _proposalContractAddress addres of the proposal contract
    */
    function _checkIfNotVoted(
        uint128 _class,
        uint128 _nonce,
        address _proposalContractAddress
    ) internal view returns(bool) {
        bytes32 _hash = _hashVote(msg.sender, _class, _nonce, _proposalContractAddress);
        bool hasVoted = _voted(_hash);
        require(hasVoted == false, "Gov: Already voted");

        return true;
    }

    /**
    * @dev return an array of zeros with same size as the input array
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _dbitDistributedPerDay array that contains DBIT to distribute per day
    */
    function _zeroArray(
        uint128 _class,
        uint128 _nonce,
        uint256[] memory _dbitDistributedPerDay
    ) internal {
        govStorage.getProposal(_class,_nonce).totalVoteTokensPerDay = _dbitDistributedPerDay;
        
        for(uint256 i = 0; i < _dbitDistributedPerDay.length; i++) {
            govStorage.getProposal(_class,_nonce).totalVoteTokensPerDay[i] = 0;
        }
    }

    /**
    * @dev return the last nonce of a given class
    * @param _class proposal class
    */
    function _getClassLastNonce(uint128 _class) internal view returns(uint256) {
        return    govStorage.getClassNonceInfo(_class);
    }

  
}

/// @title A Proposal factory : provides the API to execute the changes in the given proposal.
/// @notice this will be setting 
/// @dev Explain to a developer any extra details

import "./interfaces/IProposalFactory.sol";
//import "Debond-Exchange/contracts/interfaces/I"
import "./interfaces/external/IBank.sol";

import"./interfaces/external/IExchange.sol";

contract  ProposalFactory  is IProposalFactory, Governance {

    address dataContract;
    constructor( address _dbit,
        address _dGoV,
        address _stakingContract,
        address _voteToken,
        address _debondOperator,
        address _debondTeam,
        uint256 _dbitAmountForVote,
        address _governanceStorage,
        address dataAddress) Governance(_dbit,
         _dGoV,
         _stakingContract,
         _voteToken,
         _debondOperator,
         _debondTeam,
         _dbitAmountForVote,
         _governanceStorage,
         dataAddress) {
             dataContract = dataAddress;
    } 

        //modifiers
    modifier onlyProposalExecution(uint _class , uint _nonce) {
    require(msg.sender == govStorage.getProposal(_class, _nonce).contractAddress, "only proposal contract  address owner can execute");
    _;
    }

    modifier onlyApproved(uint _class , uint _nonce) {
    require(govStorage.getProposal(_class,_nonce).status ==IGovStorage.ProposalStatus.Approved, "only passed proposal should execute the function");
    _;
    }

    modifier onlyActiveOrPausedProposal(uint128 _class, uint128 _nonce) {
        IGovStorage.Proposal memory _proposal = govStorage.getProposal(_class,_nonce);
        require(
            (
                _proposal.endTime >= block.timestamp &&
                _proposal.status == IGovStorage.ProposalStatus.Approved
            ) || _proposal.status == IGovStorage.ProposalStatus.Paused,
            "Gov: not active or paused"
        );
        _;
    }
  

    
   


     /** 
    * @dev revokes a proposal by another proposal of higher priority 
    * @param _class proposal class
    * @param _nonce proposal nonce
    */

  function revokeProposal(
        uint128 _class,
        uint128 _nonce,
        uint128 revoking_class,
        uint128 revoking_nonce
    ) external onlyProposalExecution(_class,_nonce) onlyApproved(_class,_nonce) override  onlyActiveOrPausedProposal(_class, _nonce) {
        require(revoking_class > _class , "proposal with higher priority can revoke the give proposal");
        govStorage.setProposalStatus(_class,_nonce, IGovStorage.ProposalStatus.Revoked);
        emit proposalRevoked(_class, _nonce);
    }

    /** sets the allocation for the given member 
     */
    function addAllocationMember(address _for , uint _allocatedDGOVMinted , uint _allocatedDBITMinted , uint _dbitAllocationPPM , uint _dgovAllocationPPM, uint _class, uint _nonce) external {
        require(msg.sender == govStorage.getProposal(_class, _nonce).contractAddress, "only proposal contract can execute");
        require(govStorage.getProposal(_class, _nonce).status  == IGovStorage.ProposalStatus.Approved,"only approved proposal");
            govStorage.setAllocatedTokenPPM(_for , _allocatedDGOVMinted, _allocatedDBITMinted);
    
    }
 

    /** for minting the allocation tokens for community member allocation
     */


    function mintAllocation(uint _class , uint _nonce , address _to , uint amountdGOV , uint amountDBIT ) external {
        require(msg.sender == govStorage.getProposal(_class, _nonce).contractAddress, "only proposal contract can execute");
        require(govStorage.getProposal(_class, _nonce).status  == IGovStorage.ProposalStatus.Approved,"only approved proposal");
        mintAllocatedToken(_to,  amountdGOV ,  amountDBIT);

    }
    /**
    adding bondClass . 
     */
    function addBondClass(uint newBondClass , uint _class, uint _nonce, string memory symbol , IDebondBond.InterestRateType interestRateType , address tokenAddress , uint periodTimestamp)   external override onlyProposalExecution(_class,_nonce)   {
    require(msg.sender == govStorage.getProposal(_class, _nonce).contractAddress, "only proposal contract can execute");
    require(govStorage.getProposal(_class,_nonce).status ==IGovStorage.ProposalStatus.Approved, "only passed proposal should execute the function");
     data.addClass(newBondClass,symbol,interestRateType,tokenAddress,periodTimestamp);
    }


    function pauseAll(uint _class , uint _nonce, bool setState ) external  onlyProposalExecution(_class,_nonce) override
    {
    require(msg.sender == govStorage.getProposal(_class, _nonce).contractAddress, "only proposal contract  address owner can execute");
    require(_class > 2, "Gov: only higher level class  proposal can execute the changes ");
    require(govStorage.getProposal(_class,_nonce).status ==IGovStorage.ProposalStatus.Approved, "only passed proposal should execute the function");
        //data.setIsActive(setState);
        //Dgov.setIsActive(setState);
        //IDebondToken(dbitAddress).setIsActive(setState);
        //IExchange(exchangeAddress).setIsActive(setState);
        //IBank(bankAddress).setIsActive(setState); 
    }


    function changeTeamAllocation(
        uint128 _class,
        uint128 _proposalNonce,
        address _to,
        uint256 _newDbitPPM,
        uint256 _newDgovPPM
    )  onlyProposalExecution(_class,_proposalNonce) public returns(bool)  {
        require(msg.sender == govStorage.getProposal(_class, _proposalNonce).contractAddress, "only proposal contract  address owner can execute");
        require(govStorage.getProposal(_class,_proposalNonce).status ==IGovStorage.ProposalStatus.Approved, "only passed proposal should execute the function");
        require(_class <= 1, "Gov: class not valid");
        require(
            checkProposal(_class, _proposalNonce) == true,
            "Gov: proposal not valid"
        );
        require(
            msg.sender == govStorage.getProposal(_class, _proposalNonce).contractAddress,
            "Gov: not proposal owner"
        );


        uint dbitAllocDistributedPPM;
        uint dgovAllocDistributedPPM;

        uint overallDBITAlloc;
        uint overallDGOVAlloc;

        uint256  maximumExecutionTime = govStorage.getProposal(_class, _proposalNonce).executionInterval;
        govStorage.setProposalExecutionInterval(_class,_proposalNonce,maximumExecutionTime - 1 );

        IGovStorage.AllocatedToken memory _allocatedToken = govStorage.getAllocatedToken(_to);
        (dbitAllocDistributedPPM ,dgovAllocDistributedPPM) = govStorage.getTotalAllocatedDistributedPPM();
        

        require(
            dbitAllocDistributedPPM - _allocatedToken.dbitAllocationPPM + _newDbitPPM <= dbitBudgetPPM,
            "Gov: too much"
        );

        require(
            dgovAllocDistributedPPM - _allocatedToken.dgovAllocationPPM + _newDgovPPM <= dgovBudgetPPM,
            "Gov: too much"
        );
        // TODO: also to check whether these values are actually lower than the max Allocated supply by the DBIT/DBGT. 


        (uint dbitTokenAllocatedPPM , uint dgovTokenAllocatedPPM ) = govStorage.getAllocatedTokenPPM(_to); 

        overallDBITAlloc = dbitAllocDistributedPPM - dbitTokenAllocatedPPM + _newDbitPPM;
        overallDGOVAlloc = dgovAllocDistributedPPM - dgovTokenAllocatedPPM + _newDgovPPM;

        govStorage.setTotalAllocationDistributed(overallDBITAlloc, overallDGOVAlloc);
        govStorage.setAllocatedTokenPPM(_to, _newDbitPPM , _newDgovPPM);


        return true;
    }

      
    function changeCommunityFundSize(
        uint128 _class,
        uint128 _nonce,
        uint256 _newDBITBudget,
        uint256 _newDGOVBudget
    ) public  onlyProposalExecution(_class,_nonce) override returns(bool) {
        
        
        require(msg.sender == govStorage.getProposal(_class, _nonce).contractAddress, "only proposal contract  address owner can execute");
        require(govStorage.getProposal(_class,_nonce).status ==IGovStorage.ProposalStatus.Approved, "only passed proposal should execute the function");     
        require(_class < 1, "Gov: class not valid");
        require(
            checkProposal(_class, _nonce) == true,
            "Gov: proposal not valid"
        );
        require(
            msg.sender == govStorage.getProposal(_class,_nonce).owner,
            "Gov: not proposal owner"
        );
        // TODO: Sam is there any reason for decreasinf the execution interval ? we need to check the condition  for  the reduction of time < 1 second
        uint256  maximumExecutionTime = govStorage.getProposal(_class, _nonce).executionInterval;
        govStorage.getProposal(_class, _nonce).executionInterval = maximumExecutionTime - 1;

        dbitBudgetPPM = _newDBITBudget;
        dgovBudgetPPM = _newDGOVBudget;

        return true;
    }



    function updatePurchesableClasses(uint debondClassId, uint proposalClass, uint ProposalNonce ,  uint[] calldata purchaseClassId, bool[] calldata purchasable) onlyProposalExecution(proposalClass,proposalClass)  override external  {
    require(msg.sender == govStorage.getProposal(proposalClass, ProposalNonce).contractAddress, "only proposal contract  address owner can execute");
    require(govStorage.getProposal(proposalClass,ProposalNonce).status ==IGovStorage.ProposalStatus.Approved, "only passed proposal should execute the function");
  //  require(IData(dataContract).allDebondClasses()[debondClassId] !=0, "the debondClass is not present already" );
    require(purchaseClassId.length == purchasable.length , "bool array and classiD should be of same length" );
     for(uint i = 0; i < purchaseClassId.length; i++ )
        {   
            IData(dataContract).updatePurchasableClass(debondClassId, purchaseClassId[i], purchasable[i]); 
        }    
    }

    function addProposalClass(
        uint256 _newProposalClass,
        uint256 proposal_class,
        uint256 proposal_nonce,
        uint256 _class,
        uint _timelock, 
        uint _minimumApproval, 
        uint _minimumVote, 
        bool _architectVeto, 
        uint _maximumExecutionTime, 
        uint _minimumExecutionTime
    ) external override returns (bool)
    {
    require(msg.sender == govStorage.getProposal(proposal_class, proposal_nonce).contractAddress, "only proposal contract  address owner can execute");
    require(govStorage.getProposal(proposal_class,proposal_nonce).status ==IGovStorage.ProposalStatus.Approved, "only passed proposal should execute the function");
    govStorage.registerProposalClassInfo(_newProposalClass, _timelock, _minimumApproval, _minimumVote, _architectVeto, _maximumExecutionTime,_minimumExecutionTime);
    return true;
    }

   


    function claimFundForProposal(
        uint128 _class,
        uint128 _proposalNonce,
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) public override onlyProposalExecution(_class,_proposalNonce) returns(bool) {

        require(_class <= 2, "Gov: class not valid");
        require(
            checkProposal(_class, _proposalNonce) == true,
            "Gov: proposal not valid"
        );
        require(
            msg.sender == govStorage.getProposal(_class,_proposalNonce).contractAddress,
            "Gov: not proposal owner"
        );

        uint256 _dbitTotalSupply = IDebondToken(dbitAddress).totalSupply();
        uint256 _dgovTotalSupply = Dgov.totalSupply();

        uint256  maximumExecutionTime = govStorage.getProposal(_class,_proposalNonce).executionInterval;
        govStorage.setProposalExecutionInterval(_class, _proposalNonce, maximumExecutionTime - 1); 
       
       (uint dbitTotalAllocationDistributed, uint dgovTotalAllocationDistributed) = govStorage.getTotalAllocatedDistributed();
       (uint  dbitAllocationDistibutedPPM , uint dgovAllocationDistibutedPPM ) = govStorage.getTotalAllocatedDistributedPPM();
       (uint dbitBudgetPPM , uint dgovBudgetPPM) = govStorage.getBudgetPPM();
        
        require(
            _amountDBIT <= (_dbitTotalSupply - dbitTotalAllocationDistributed) / 1e6 * 
                           (dbitBudgetPPM - dbitAllocationDistibutedPPM),
            "Gov: DBIT amount not valid"
        );
        require(
            _amountDGOV <= (_dgovTotalSupply - dgovTotalAllocationDistributed) / 1e6 * 
                           (dgovBudgetPPM - dgovAllocationDistibutedPPM),
            "Gov: DGOV amount not valid"
        );

        IDebondToken(dbitAddress).mintAllocatedSupply(_to, _amountDBIT);
        Dgov.mintAllocatedSupply(_to, _amountDGOV);


        (uint dbitAllocPPM , uint dgovAllocPPM) = govStorage.getAllocatedTokenPPM(_to);
        govStorage.setAllocatedTokenPPM(_to,dbitAllocPPM + _amountDBIT  , dgovAllocPPM + _amountDGOV);
        govStorage.setTotalAllocationDistributed(dbitTotalAllocationDistributed + _amountDBIT ,dgovTotalAllocationDistributed + _amountDGOV);

        return true;

    }



    function setDovVMaxSupply(uint _maxSupplyDGOV) external onlyDebondOperator {
        Dgov.setMaximumSupply(_maxSupplyDGOV);
    } 


    function setBenchmarkInterestRate(uint proposalClass , uint proposalNonce , uint _newRate) external onlyApproved(_class ,_nonce)    returns(bool) {
        govStorage.setBenchmarkInterestRate(_newRate);
        return(true);
    }




}
/**
1. adding function to  change the proposal
- check the modifiers to check the integration with  the EPOCH. (NIMP).
-  benchmarkInterest changed.
- adding function to set ERC20
 */