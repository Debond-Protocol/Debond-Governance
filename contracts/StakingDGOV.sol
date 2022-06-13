pragma solidity ^0.8.0;
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
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IStakingDGOV.sol";
import "./interfaces/IVoteToken.sol";

import "debond-token/contracts/interfaces/IdGOV.sol";


import "debond-token/contracts/interfaces/IDebondToken.sol";
import "./interfaces/IGovStorage.sol";

import "./utils/GovernanceOwnable.sol";

import "./Pausable.sol";


contract StakingDGOV is IStakingDGOV, ReentrancyGuard, GovernanceOwnable  {
   // sets the dbit amount for an vote.
   uint _dbitAmountForOneVote;

   event voteTokenRedeemed(address _voter, address _to,uint  _class, uint _nonce, address _contractAddress);


    /**
    * @dev structure that stores information on the stacked dGoV
    */

    struct StackedDGOV {
        uint256 amountDGOV;
        uint256 startTime;
        uint256 duration;
    }

    address public dGov;
    address public debondOperator;
    address public governance;
    address public govStorage;

    uint256 private interestRate;
    uint256 constant private NUMBER_OF_SECONDS_IN_YEAR = 31536000;


    IGovStorage Storage;
    IDebondToken token;
    IdGOV IdGov;
    IVoteToken IVote;

    mapping(address => StackedDGOV) public stackedDGOV;

    modifier onlyGov {
        require(msg.sender == governance, "Gov: not governance");
        _;
    }

    modifier onlyDebondOperator {
        require(msg.sender == debondOperator, "Gov: not governance");
        _;
    }

    constructor (
        address _dbit,
        address _dGovToken,
        address _voteToken,
        address _debondOperator,
        uint256 _interestRate,
        address GovStorage,
        address _governanceAddress
    ) GovernanceOwnable(_governanceAddress)
    
    {
        dbit = _dbit;
        dGov = _dGovToken;
        voteToken = _voteToken;
        debondOperator = _debondOperator;
        interestRate = _interestRate;
        govStorage = GovStorage;
        Storage = IGovStorage(govStorage);
        IdGov = IdGOV(dGov);
        IVote = IVoteToken(voteToken);
        token = IDebondToken(_dbit);
    }

    /**
    * @dev stack dGoV tokens
    * @param _staker the address of the staker
    * @param _amount the amount of dGoV tokens to stak
    * @param _duration the staking period
    */
    function stakeDgovToken(
        address _staker,
        uint256 _amount,
        uint256 _duration
    ) external onlyGov nonReentrant() {
       
        // getting only the unlockedSupply : thats (allocated + airdropped + minted supply ).
        uint256 stakerBalance = IdGov.balance(_staker);
        require(_amount <= stakerBalance, "Debond: not enough dGov unlocked supply");

        stackedDGOV[_staker].startTime = block.timestamp;
        stackedDGOV[_staker].duration = _duration;
        stackedDGOV[_staker].amountDGOV += _amount;

        IdGov.transferFrom(_staker, address(this), _amount);
        IVote.mintVoteToken(_staker, _amount);
        emit dgovStacked(_staker, _amount);
    }

    /**
    * @dev unstack dGoV tokens
    * @param _staker the address of the staker
    * @param _to the address to send the dGoV to
    * @param _amount the amount of dGoV tokens to unstak
    */
    function _unstakeDgovToken(
        address _staker,
        address _to,
        uint256 _amount
    ) internal   nonReentrant() {
        StackedDGOV memory _stacked = stackedDGOV[_staker];
        require(
            block.timestamp >= _stacked.startTime + _stacked.duration,
            "Staking: still staking"
        );
        require(_amount <= _stacked.amountDGOV, "Staking: Not enough dGoV staked");

        // burn the vote tokens owned by the user
        IVoteToken Ivote = IVoteToken(voteToken);
        Ivote.burnVoteToken(_staker, _amount);

        // transfer staked DGOV to the staker 
        IdGOV _IdGov =IdGOV(dGov);
        IdGov.transfer(_to, _amount);

        emit dgovUnstacked(_staker, _to, _amount);
    }


    /**
    * @dev get the governance contract address
    * @param gov governance contract address
    */
    function getGovernanceContract() external view returns(address gov) {
        gov = governance;
    }

    /**
    * @dev set the interest rate of DBIT to gain when unstaking dGoV
    * @param _interest The new interest rate
    */
    function setInterestRate(uint256 _interest) external onlyDebondOperator {
        interestRate = _interest;
    }

    /**
    * @dev get the interest rate of DBIT to gain when unstaking dGoV
    * @param _interestRate The interest rate
    */
    function getInterestRate() public view returns(uint256 _interestRate) {
        _interestRate = interestRate;
    }

    /**
    * @dev get the amount of dGoV staked by a user
    * @param _user address of the user
    * @param _stakedAmount amount of dGoV staked by the user
    */
    function getStakedDGOV(address _user) external view returns(uint256 _stakedAmount) {
        _stakedAmount = stackedDGOV[_user].amountDGOV;
    }

    /** TODO:  : set by the staking parameters  
    * @dev returns the amount of DBIT to get for one vote token
    * @param dbitAmount DBIT amount
    */
    function getDBITAmountForOneVote(uint128 _class, uint128 _nonce) public view returns(uint256 dbitAmount) {
        dbitAmount = _dbitAmountForOneVote;
    }


    /** TODO: will go to ProposalFactory contract.
    * @dev sets the amount of DBIT to get for one vote token
    * @param _dbitAmount the new amount of the tokens needed by the standard.
    */
    function setDBITAmountForOneVote(uint256 _dbitAmount) public onlyDebondOperator   returns(bool) {
        _dbitAmountForOneVote = _dbitAmount;
        return(true);
    }



    /**
    * @dev calculate the interest earned in DBIT
    * @param _staker the address of the dGoV staker
    * @param interest interest earned
    */
    function calculateInterestEarned(
        address _staker
    ) external view onlyGov returns(uint256 interest) {
        StackedDGOV memory staked = stackedDGOV[_staker];
        require(staked.amountDGOV > 0, "Staking: no dGoV staked");

        uint256 _interestRate = getInterestRate();

        interest = _interestRate * staked.duration / NUMBER_OF_SECONDS_IN_YEAR;
    }

    /**
    * @dev Estimate how much Interest the user has gained since he staked dGoV
    * @param _amount the amount of DBIT staked
    * @param _duration staking duration to estimate interest from
    * @param interest the estimated interest earned so far
    */
    function estimateInterestEarned(
        uint256 _amount,
        uint256 _duration
    ) external view returns(uint256 interest) {
        uint256 _interestRate = getInterestRate();
        interest = _amount * (_interestRate * _duration / NUMBER_OF_SECONDS_IN_YEAR);
    }

    /**
    * @dev update the stakedDGOV struct after a staker unstake dGoV
    * @param _staker the address of the staker
    * @param _amount the amount of dGoV token that have been unstake
    * @param updated true if the struct has been updated, false otherwise
    */
    function _updateStakedDGOV(
        address _staker,
        uint256 _amount
    )  internal returns(bool updated) {
        stackedDGOV[_staker].amountDGOV -= _amount;

        updated = true;
    }

    /**
    * @dev returns a hash for  the vote (just for calculation of the internal rewards by finding the keys)
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
        IGovStorage.Proposal memory _proposal = govStorage.getProposal(_class,_nonce);
        uint256 proposalDurationInDay = _proposal.dbitDistributedPerDay.length;

        bytes32 _hash = _hashVote(_voter, _class, _nonce, _contractAddress);
        IGovStorage.Vote memory _userVote = govStorage.getVoteDetails(_hash);
        uint256 votingDay = _userVote.votingDay;

        numberOfDay = (proposalDurationInDay - votingDay) + 1;
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
        IGovStorage.Proposal memory _proposal = govStorage.getProposal(_class,_nonce);

        uint256 proposalDurationInDay = _proposal.dbitDistributedPerDay.length;
        uint256 numberOfDays = _getNumberOfDaysRewarded(_voter, _class, _nonce, _contractAddress);
        require(numberOfDays <= proposalDurationInDay, "Gov: Invalid vote");

        bytes32 _hash = _hashVote(_voter, _class, _nonce, _contractAddress);
        IGovStorage.Vote memory _userVote = govStorage.getVoteDetails(_hash);

        uint256 _reward = 0;
        for(uint256 i = proposalDurationInDay - numberOfDays; i < numberOfDays; i++) {
            _reward += _proposal.dbitDistributedPerDay[i] / _proposal.totalVoteTokensPerDay[i];
        }

        _reward = _reward * _userVote.amountTokens;

        // burn vote tokens owned by the user
         govStorage.setAmountsToken(_hash,0);

        IVoteToken _voteTokenContract = IVoteToken(voteToken);
        _voteTokenContract.burnVoteToken(_voter, _userVote.amountTokens);

        // transfer DBIT interests to user
        
        token.transferFrom(dbitAddress, _to, _reward);

        _transfered = true;
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
        IGovStorage.Proposal memory _proposal = govStorage.getProposal(_class,_nonce);
        require(block.timestamp > _proposal.endTime, "Gov: still voting");

        bytes32 _hash = _hashVote(_voter, _class, _nonce, _contractAddress);
        IGovStorage.Vote memory _userVote = govStorage.getVoteDetails(_hash);
       
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
    * @dev unstake DGOV tokens and gain DBIT interests
    * @param _staker the address of the staker
    * @param _amount the amount of DGOV to stake
    * @param _to address to which DGOV tokens are sent back
    * @param unstaked true if tokens have been staked, false otherwise
    */
    function _unstakeAndPayDBIT(
        address _staker,
        address _to,
        uint256 _amount
    ) external returns(bool unstaked) {
        
        _unstakeDgovToken(_staker, _to, _amount);

        uint256 interest = this.calculateInterestEarned(_staker);
        require(this.updateStakedDGOV(_staker, _amount), "Gov: don't have enough DGOV");
          
        token.transfer( _to, _amount * interest);

        unstaked = true;
    }

}