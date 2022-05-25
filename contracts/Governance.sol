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
import "./test/DBIT.sol";
import "./Pausable.sol";
import "./interfaces/IGovStorage.sol";
import "debond-token/contracts/interfaces/IdGOV.sol";

//import "Debond-Exchange/contracts/interfaces/IExchange.sol";
import "debond-bank/contracts/interfaces/IData.sol";





contract Governance is  IGovernance, ReentrancyGuard, Pausable {

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
    IdGOV dgov;


    // address  for token address.
    address DBIT;
    address dGOV;
    address voteToken;
    address _dbitAmountForOneVote;
    address debondOperator; // ad
    address debondTeam; // this is the treasury for the debondTeam for paying the allcoation 
    address stakingContract;




    // CONSTANTS :

    // defines the maximum time BUDGET for PPM  for sharing.
    uint private dbitBudgetPPM;
    uint private dgovBudgetPPM;

    //enums 
    event ProposalApprovalStatus(uint _class , uint nonce , ProposalStatus Status);

    //modifier 

     modifier onlyDebondOperator {
        require(msg.sender == debondOperator, "Gov: not governance");
        _;
    }

    modifier onlyActiveProposal(uint _class, uint  _nonce) {
        require(govStorage.getProposal(_class, _nonce).status == IGovStorage.ProposalStatus.Active, "NOT ACTIVE");
        _;
    }

    modifier onlyPausedProposal(uint _class, uint  _nonce) {
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
        uint256 _dbitAmountForVote,
        address _governanceStorage,
        address dataAddress
    )  {
        DBIT = _dbit;
        dGOV = _dGoV;
        voteToken = _voteToken;
        stakingContract = _stakingContract;
        _dbitAmountForOneVote = _dbitAmountForVote;
        debondOperator = _debondOperator;
        debondTeam = _debondTeam;
        govStorage = IGovStorage(govStorage); 
        data = IData(dataAddress);
        dgov = IdGOV(_dGoV);

        // with parameter dbitAllocationPPM and dgovAllocationPPM.
        govStorage.setAllocatedTokenPPM(debondTeam, 8e4 * 1 ether, 4e4 * 1 ether);
        uint dbitTotalAllocationDistributed = 85e3 * 1 ether;
        uint dgovTotalAllocationDistributed = 8e4 * 1 ether;
        dgov.setTotalAllocationDistributed(dbitTotalAllocationDistributed,dgovTotalAllocationDistributed);
        
        dbitBudgetPPM = 1e5 * 1 ether;
        dgovBudgetPPM = 1e5 * 1 ether;

    // with parameters timelock, minimumApproval , _minimumVote , _architectVeto , _maximumExecutionTime , _minimumExecutionInterval.
    govStorage.registerProposalClassInfo(0,3,150,30,0,3,1);
    govStorage.registerProposalClassInfo(1,3,170,60,1,5,2);
    govStorage.registerProposalClassInfo(2,3,300,70,1,11,3);
     
    }

    /** TODO: will go to ProposalFactory contract.
    * @dev sets the amount of DBIT to get for one vote token
    * @param _dbitAmount DBIT amount
    */
    function setDBITAmountForOneVote(uint256 _dbitAmount) public onlyDebondOperator {
        _dbitAmountForOneVote = _dbitAmount;
    }

    // /** TODO: set by governance ownable and GovStorage
    // * @dev set the governance contract address
    // * @param _governanceAddress new governance contract address
    // */
    // function setGovernanceAddress(address _governanceAddress) external {
    //     require(_governanceAddress != governance, "Gov: same Gov. address");

    //     governance = _governanceAddress;
    // }

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
        require(msg.sender == govStorage.getProposal(_class,_nonce).owner || msg.sender == govStorage.debondOperator, "only owner or the admin can pause proposal");
        govStorage.setProposalStatus(_class , _nonce , govStorage.ProposalStatus.Approve);
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
       govStorage.getProposal(_class,_nonce).status = ProposalStatus.Approved;
        emit proposalUnpaused(_class, _nonce);
    }
    /**
    * @dev sets  the  proposal  status (used  by debondOperator if the given proposal has the ProposalApprove.CanVeto defined).
    * @param _class proposal class
    * @param _nonce proposal nonce
    * 
    */
    function approvalProposal(
        uint128 _class,
        uint128 _nonce,
        IGovStorage.ProposalStatus  Status // 
    ) external  onlyActiveProposal(_class, _nonce) onlyDebondOperator {
        if(govStorage.getProposal(_class, _nonce).approvalMode == IGovStorage.ProposalApproval.CanVeto)
{
        govStorage.setProposalStatus(_class,_nonce).status = Status;
        emit ProposalApprovalStatus(_class, _nonce, Status);
    
}
else if(govStorage.getProposal(_class, _nonce).approvalMode == IGovStorage.ProposalApproval.ShouldApprove)
{
    govStorage.setProposalStatus(_class,_nonce).status = IGovStorage.ProposalStatus.Approved;
        emit ProposalApprovalStatus(_class, _nonce, IGovStorage.ProposalStatus.Approved);
}
  
    }

      /** TODO: will be set by the ProposalFactory . 
    * @dev returns the amount of DBIT to get for one vote token
    * @param dbitAmount DBIT amount
    */
    function getDBITAmountForOneVote(uint128 _class, uint128 _nonce) public view returns(uint256 dbitAmount) {
         require(msg.sender == getProposal(proposal_class, proposal_nonce).contractAddress, "only proposal contract can execute");
        require(getProposal(proposal_class, proposal_nonce).status  == ProposalStatus.Approved,"only approved proposal");
        dbitAmount = _dbitAmountForOneVote;
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
        VoteChoice _userVote,
        uint256 _amountVoteTokens
    ) external onlyActiveProposal(_class, _nonce) nonReentrant() returns(bool voted) {
        // require the vote to be in progress
        Proposal memory _proposal = govStorage.getProposalDetails(_class,_nonce);

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
    * @dev redeem vote tokens and get dbit interest
    * @param _voter the address of the voter
    * @param _to address to send interest to
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _contractAddress proposal contract address
    */
    function redeemVoteTokenForDBIT(
        address _voter,
        address _to,
        uint128 _class,
        uint128 _nonce,
        address _contractAddress
    ) external nonReentrant() {
        Proposal memory _proposal = govStorage.getProposal(_class,_nonce);
        require(block.timestamp > _proposal.endTime, "Gov: still voting");

        bytes32 _hash = _hashVote(_voter, _class, _nonce, _contractAddress);
        IGovStorage.Vote memory _userVote = govStorage.getProposalDetails();
       // Vote memory _userVote = votes[_hash];
        require(_userVote.voted == true, "Gov: you haven't voted");
        require(_userVote.amountTokens > 0, "Gov: no tokens");
        require(_userVote.votingDay > 0, "Gov: invalid vote");

        require(
            _transferDBITInterest(
                _voter,
                _to,
                _class,
                _nonce,
                _contractAddress
            ),
            "Gov: cannot transfer DBIT interest"
        );

        emit voteTokenRedeemed(_voter, _to, _class, _nonce, _contractAddress);
    }

    /**
    * @dev stake DGOV tokens and gain DBIT interests
    * @param _staker the address of the staker
    * @param _amount the amount of DGOV to stake
    * @param _duration the time the tokens wiull be staked
    * @param staked true if tokens have been staked, false otherwise
    */
    function stakeDGOV(
        address _staker,
        uint256 _amount,
        uint256 _duration
    ) external returns(bool staked) {
        IStakingDGOV IStaking = IStakingDGOV(stakingContract);
        IStaking.stakeDgovToken(_staker, _amount, _duration);

        staked = true;
    }

    /**
    * @dev unstake DGOV tokens and gain DBIT interests
    * @param _staker the address of the staker
    * @param _amount the amount of DGOV to stake
    * @param _to address to which DGOV tokens are sent back
    * @param unstaked true if tokens have been staked, false otherwise
    */
    function unstakeDGOV(
        address _staker,
        address _to,
        uint256 _amount
    ) external returns(bool unstaked) {
        IStakingDGOV IStaking = IStakingDGOV(stakingContract);
        IStaking.unstakeDgovToken(_staker, _to, _amount);

        // transfer the interest earned in DBIT to the staker
        uint256 interest = IStaking.calculateInterestEarned(_staker);
        require(IStaking.updateStakedDGOV(_staker, _amount), "Gov: don't have enough DGOV");
        IERC20 Idbit = IERC20(DBIT);
        Idbit.transfer(_to, _amount * interest);

        unstaked = true;
    }

    /**
    * @dev mint allocated DBIT to a given address
    * @param _to the address to mint DBIT to
    * @param _amountDBIT the amount of DBIT to mint
    * @param _amountDGOV the amount of DGOV to mint
    */
    function mintAllocatedToken(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) public returns(bool) {
        AllocatedToken memory _allocatedToken = allocatedToken[_to];

        uint256 _dbitCollaterizedSupply = IDebondToken(DBIT).collaterisedSupply();
        uint256 _dgovCollaterizedSupply = IDebondToken(dGoV).collaterisedSupply();

        require(
            IDebondToken(DBIT).allocatedBalance(_to) + _amountDBIT <=
            _dbitCollaterizedSupply * _allocatedToken.dbitAllocationPPM / 1 ether,
            "Gov: not enough supply"
        );
        require(
            IDebondToken(dGoV).allocatedBalance(_to) + _amountDGOV <=
            _dgovCollaterizedSupply * _allocatedToken.dgovAllocationPPM / 1 ether,
            "Gov: not enough supply"
        );

        IDebondToken(DBIT).mintAllocatedSupply(_to, _amountDBIT);
        allocatedToken[_to].allocatedDBITMinted += _amountDBIT;
        dbitTotalAllocationDistributed += _amountDBIT;

        IDebondToken(dGoV).mintAllocatedSupply(_to, _amountDGOV);
        allocatedToken[_to].allocatedDGOVMinted += _amountDGOV;
        dgovTotalAllocationDistributed += _amountDGOV;

        return true;
    }
    /**
    * @dev return a proposal
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _proposal proposal for class `_class` and nonce `_nonce`
    */
    function getProposal(
        uint128 _class,
        uint128 _nonce
    ) external view returns(Proposal memory _proposal) {
      govStorage.getProposalDetails(_class,_nonce);
    }

    /**
    * @dev check a proposal
    */
    function checkProposal(
        uint128 _class,
        uint128 _nonce
    ) public view returns(bool) {
    Proposal memory _proposal = govStorage.getProposal(_class,_nonce);
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

        require(
            uint256(_proposal.approvalMode) <= _proposalClassInfo.architectVeto,
            "Gov: Architect"
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
    ) external view returns(ProposalClassInfo memory _classInfo) {
//        _classInfo = proposalClassInfo[_class];
        _classInfo = govStorage.getProposalClassInfo(_class);


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
    * @dev Transfer DBIT interests earned by voting
    * @param _voter the address of the voter
    * @param _to the address to which to send interests
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _contractAddress proposal contract address
    */
    function _transferDBITInterest(
        address _voter,
        address _to,
        uint128 _class,
        uint128 _nonce,
        address _contractAddress
    ) internal returns(bool _transfered) {
        Proposal memory _proposal = govStorage.getProposal(_class,_nonce);

        uint256 proposalDurationInDay = _proposal.dbitDistributedPerDay.length;
        uint256 numberOfDays = _getNumberOfDaysRewarded(_voter, _class, _nonce, _contractAddress);
        require(numberOfDays <= proposalDurationInDay, "Gov: Invalid vote");

        bytes32 _hash = _hashVote(_voter, _class, _nonce, _contractAddress);
        Vote memory _userVote = votes[_hash];

        uint256 _reward = 0;
        for(uint256 i = proposalDurationInDay - numberOfDays; i < numberOfDays; i++) {
            _reward += _proposal.dbitDistributedPerDay[i] / _proposal.totalVoteTokensPerDay[i];
        }

        _reward = _reward * _userVote.amountTokens;

        // burn vote tokens owned by the user
        votes[_hash].amountTokens = 0;
        IVoteToken _voteTokenContract = IVoteToken(voteToken);
        _voteTokenContract.burnVoteToken(_voter, _userVote.amountTokens);

        // transfer DBIT interests to user
        IERC20 _dbit = IERC20(DBIT);
        _dbit.transferFrom(DBIT, _to, _reward);

        _transfered = true;
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
        Proposal memory _proposal
    ) internal {
        bytes32 hash = _hashVote(msg.sender, _class, _nonce, _contractAddress);

        // // these are total for votes 
        // // TODO:  we can also get the details  from govStorage.getProposal(_class,_nonce); 
         uint256 forVotes = govStorage.getProposal(_class,_nonce).forVotes;
         uint256 againstVotes = govStorage.getProposal(_class,_nonce).againstVotes;


        govStorage.setProposalVote(_class,_nonce,_amount, _userVote,  hash, forVotes, againstVotes);
        
        govStorage.getProposal(_class,_nonce).numberOfVoters += 1;
       
        _updateTotalVoteTokensPerDay(_class, _nonce, _amount);

        votes[hash].class = _class;
        votes[hash].nonce = _nonce;
        votes[hash].contractAddress = _contractAddress;
        votes[hash].voted = true;
        votes[hash].amountTokens = _amount;
        votes[hash].votingDay = _getVotingDay(_class, _nonce);

        uint votingDay =  _getVotingDay(_class, _nonce);

        govStorage._registerVote(
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
        govStorage.getProposal(_class,_nonce).totalVoteTokensPerDay[day] = totalVoteTokensPerDay + _amountVoteTokens;
    }

    /**
    * @dev get the bnumber of days elapsed since the vote has started
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param day the current voting day
    */
    function _getVotingDay(uint128 _class, uint128 _nonce) internal view returns(uint256 day) {
        Proposal memory _proposal = govStorage.getProposal(_class,_nonce);

        uint256 duration = _proposal.startTime > block.timestamp ?
            _proposal.startTime - block.timestamp:
            block.timestamp - _proposal.startTime;
        
        day = (duration / NUMBER_OF_SECONDS_IN_DAY);
    }

    /**
    * @dev get the bnumber of days elapsed since the user has voted
    * @param _voter the address of the voter
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _contractAddress proposal contract address
    * @param numberOfDay the number of days
    */
    function _getNumberOfDaysRewarded(
        address _voter,
        uint128 _class,
        uint128 _nonce,
        address _contractAddress
    ) internal view returns(uint256 numberOfDay) {
        Proposal memory _proposal = govStorage.getProposal(_class,_nonce);
        uint256 proposalDurationInDay = _proposal.dbitDistributedPerDay.length;

        bytes32 _hash = _hashVote(_voter, _class, _nonce, _contractAddress);
        Vote memory _userVote = votes[_hash];
        uint256 votingDay = _userVote.votingDay;

        numberOfDay = (proposalDurationInDay - votingDay) + 1;
    }

    /**
    * @dev Check if a user already voted for a proiposal
    * @param _hash vote hash
    * @param voted true if already voted, false if not
    */
    function _voted(bytes32 _hash) internal view returns(bool voted) {
        voted = votes[_hash].voted;
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
    * @param lastNonce the last nonce of the class
    */
    function _getClassLastNonce(uint128 _class) internal view returns(uint256 lastNonce) {
        return proposalClass[_class].nonce;
    }

  
}

/// @title A Proposal factory : provides the API to execute the changes in the given proposal.
/// @notice this will be setting 
/// @dev Explain to a developer any extra details




contract  ProposalFactory  is Governance, GovernanceOwnable {

        //modifiers
    modifier onlyProposalExecution() {
    require(msg.sender == getProposal(proposal_class, proposal_nonce).contractAddress, "only proposal contract  address owner can execute");
    _;
    }

    modifier onlyApproved( ) {
    require(getProposal(proposal_class,proposal_nonce).status ==ProposalStatus.Approved, "only passed proposal should execute the function");
    _;
    }

    modifier onlyActiveOrPausedProposal(uint128 _class, uint128 _nonce) {
        Proposal memory _proposal = govStorage.getProposalDetails(_class,_nonce);
        require(
            (
                _proposal.endTime >= block.timestamp &&
                _proposal.status == ProposalStatus.Approved
            ) || _proposal.status == ProposalStatus.Paused,
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
    ) external onlyProposalExecution onlyApproved  onlyActiveOrPausedProposal(_class, _nonce) {
        require(revoking_class > _class , "proposal with higher priority can revoke the give proposal");
        govStorage.setProposalStatus(_class,_nonce).status = ProposalStatus.Revoked;
        emit proposalRevoked(_class, _nonce);
    }

    /** adds another address to receive the allocation 
     */
    function addAllocationMember(address _for , uint _allocatedDGOVMinted , uint _allocatedDBITMinted , uint _dbitAllocationPPM , uint _dgovAllocationPPM, uint proposal_class, uint proposal_nonce) external {
        require(msg.sender == getProposal(proposal_class, proposal_nonce).contractAddress, "only proposal contract can execute");
        require(getProposal(proposal_class, proposal_nonce).status  == ProposalStatus.Approved,"only approved proposal");
            govStorage.setAllocatedToken(_for , _allocatedDGOVMinted, _allocatedDBITMinted, _dbitAllocationPPM , _dgovAllocationPPM);
    }
 

    /** for minting the allocation tokens for community member allocation
     */


    function mintAllocation(uint _class , uint _nonce , address _to , uint amountdGOV , uint amountDBIT ) external {
        require(msg.sender == getProposal(proposal_class, proposal_nonce).contractAddress, "only proposal contract can execute");
        require(getProposal(proposal_class, proposal_nonce).status  == ProposalStatus.Approved,"only approved proposal");
        mintmintAllocatedToken(_to,  amountdGOV ,  amountDBIT);

    }
    /**
    adding bondClass . 
     */
    function addBondClass(uint newBondClass , uint proposal_class, uint proposal_nonce, string memory symbol , InterestRateType interestRateType , address tokenAddress , uint periodTimestamp)  external onlyProposalExecution onlyExecution  {
    require(msg.sender == getProposal(proposal_class, proposal_nonce).contractAddress, "only proposal contract can execute");
    require(getProposal(proposal_class,proposal_nonce).status ==ProposalStatus.Approved, "only passed proposal should execute the function");
     data.addClass(newBondClass,symbol,interestRateType,tokenAddress,periodTimestamp);
    }


    /**
     */
    function pauseAll(uint proposal_class , uint proposal_nonce, bool setState) external onlyProposalExecution onlyExecution
    {
    require(msg.sender == getProposal(proposal_class, proposal_nonce).contractAddress, "only proposal contract  address owner can execute");
    require(getProposal(proposal_class,proposal_nonce).status ==ProposalStatus.Approved, "only passed proposal should execute the function");
        data.setActive(seetState);
        IdGOV(dGOV).setActive(setState);
        IDBIT(DBIT).setActive(setState);
      //  IExchange(exchangeAddress).setActive(setState);
      //  IBank(bankAddress).setActive(setState); 
    }

     /**
    * @dev change the team allocation  - (DBIT, DGOV)
    * @param _proposalClass class of the proposal
    * @param _proposalNonce cnonce of the proposal
    * @param _to the address that should receive the allocation tokens
    * @param _newDbitPPM the new DBIT allocation
    * @param _newDgovPPM the new DGOV allocation
    */
    function changeTeamAllocation(
        uint128 _proposalClass,
        uint128 _proposalNonce,
        address _to,
        uint256 _newDbitPPM,
        uint256 _newDgovPPM
    )  onlyProposalExecution onlyExecution public returns(bool)  {
        require(msg.sender == getProposal(proposal_class, proposal_nonce).contractAddress, "only proposal contract  address owner can execute");
        require(getProposal(proposal_class,proposal_nonce).status ==ProposalStatus.Approved, "only passed proposal should execute the function");
        require(_proposalClass <= 1, "Gov: class not valid");
        require(
            checkProposal(_proposalClass, _proposalNonce) == true,
            "Gov: proposal not valid"
        );
        require(
            msg.sender == proposal[_proposalClass][_proposalNonce].contractAddress,
            "Gov: not proposal owner"
        );

        uint256  maximumExecutionTime = proposal[_proposalClass][_proposalNonce].executionInterval;
        proposal[_proposalClass][_proposalNonce].executionInterval = maximumExecutionTime - 1;

        AllocatedToken memory _allocatedToken = allocatedToken[_to];
        uint256 dbitAllocDistributedPPM = dbitAllocationDistibutedPPM;
        uint256 dgovAllocDistributedPPM = dgovAllocationDistibutedPPM;

        require(
            dbitAllocDistributedPPM - _allocatedToken.dbitAllocationPPM + _newDbitPPM <= dbitBudgetPPM,
            "Gov: too much"
        );

        require(
            dgovAllocDistributedPPM - _allocatedToken.dgovAllocationPPM + _newDgovPPM <= dgovBudgetPPM,
            "Gov: too much"
        );

        dbitAllocationDistibutedPPM = dbitAllocDistributedPPM - allocatedToken[_to].dbitAllocationPPM + _newDbitPPM;
        allocatedToken[_to].dbitAllocationPPM = _newDbitPPM;

        dgovAllocationDistibutedPPM = dgovAllocDistributedPPM - allocatedToken[_to].dgovAllocationPPM + _newDgovPPM;
        allocatedToken[_to].dgovAllocationPPM = _newDgovPPM;

        return true;
    }

       /**
    * @dev change the community fund size (DBIT, DGOV) that is possible by the proposal only
    * @param _proposalClass class of the proposal
    * @param _proposalNonce cnonce of the proposal
    * @param _newDBITBudget new DBIT budget for community
    * @param _newDGOVBudget new DGOV budget for community
    */
    function changeCommunityFundSize(
        uint128 _proposalClass,
        uint128 _proposalNonce,
        uint256 _newDBITBudget,
        uint256 _newDGOVBudget
    ) public onlyProposalExecution onlyExecution returns(bool) {
        require(msg.sender == getProposal(proposal_class, proposal_nonce).contractAddress, "only proposal contract  address owner can execute");
        require(getProposal(proposal_class,proposal_nonce).status ==ProposalStatus.Approved, "only passed proposal should execute the function");     
        require(_proposalClass < 1, "Gov: class not valid");
        require(
            checkProposal(_proposalClass, _proposalNonce) == true,
            "Gov: proposal not valid"
        );
        require(
            msg.sender == proposal[_proposalClass][_proposalNonce].contractAddress,
            "Gov: not proposal owner"
        );

        uint256  maximumExecutionTime = getProposal(_proposalClass, _proposalNonce).executionInterval;
        getProposal(_proposalClass, _proposalNonce).executionInterval = maximumExecutionTime - 1;

        dbitBudgetPPM = _newDBITBudget;
        dgovBudgetPPM = _newDGOVBudget;

        return true;
    }

    function updatePurchesableClasses(uint debondClassId, uint proposalClass, uint ProposalNonce ,  uint[] purchaseClassId, bool purchasable) onlyProposalExecution onlyExecution external  {
    require(msg.sender == getProposal(proposal_class, proposal_nonce).contractAddress, "only proposal contract  address owner can execute");
    require(getProposal(proposal_class,proposal_nonce).status ==ProposalStatus.Approved, "only passed proposal should execute the function");
    require(IData(dataAddress).allDebondClasses()[debondClassId] !=0, "the debondClass is not present already" );
    
     for(uint i = 0; i < purchaseClassId.length; i++ )
        {
            IData(dataAddress).updatePurchasableClass(debondClassId[i], purchaseClass); 
        }    
    }




  

    /**
    * @dev claim fund for a proposal
    * @param _proposalClass class of the proposal
    * @param _proposalNonce cnonce of the proposal
    * @param _to address to transfer fund
    * @param _amountDBIT DBIT amount to transfer
    * @param _amountDGOV DGOV amount to transfer
    */
    function claimFundForProposal(
        uint128 _proposalClass,
        uint128 _proposalNonce,
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) public returns(bool) {
        require(_proposalClass <= 2, "Gov: class not valid");
        require(
            checkProposal(_proposalClass, _proposalNonce) == true,
            "Gov: proposal not valid"
        );
        require(
            msg.sender == proposal[_proposalClass][_proposalNonce].contractAddress,
            "Gov: not proposal owner"
        );

        uint256 _dbitTotalSupply = IDebondToken(DBIT).totalSupply();
        uint256 _dgovTotalSupply = IDebondToken(dGoV).totalSupply();

        uint256  maximumExecutionTime = proposal[_proposalClass][_proposalNonce].executionInterval;
        proposal[_proposalClass][_proposalNonce].executionInterval = maximumExecutionTime - 1;

        // NEED TO CHECK THIS WITH YU (see first param on require)
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

        IDebondToken(DBIT).mintAllocatedSupply(_to, _amountDBIT);
        allocatedToken[_to].allocatedDBITMinted += _amountDBIT;
        dbitTotalAllocationDistributed += _amountDBIT;

        IDebondToken(dGoV).mintAllocatedSupply(_to, _amountDGOV);
        allocatedToken[_to].allocatedDGOVMinted += _amountDGOV;
        dgovTotalAllocationDistributed += _amountDGOV;

        return true;
    }
    




}
