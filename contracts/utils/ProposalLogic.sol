pragma solidity ^0.8.0;

// SPDX-License-Identifier: apache 2.0
/*
    Copyright 2022 Debond Protocol <info@debond.org>
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
import "@openzeppelin/contracts/utils/Address.sol";
import "../interfaces/IGovStorage.sol";
import "../interfaces/IVoteToken.sol";
import "../interfaces/IStaking.sol";
import "../interfaces/IProposalLogic.sol";
import "../interfaces/IGovSharedStorage.sol";
import "../interfaces/IInterestRates.sol";

contract ProposalLogic is IProposalLogic {
    mapping(uint128 => uint256) private _votingPeriod;
    mapping(uint128 => mapping(uint128 => ProposalVote)) internal _proposalVotes;
    mapping(uint128 => mapping(uint128 => UserVoteData[])) public userVoteData;

    event votingDelaySet(uint256 oldDelay, uint256 newDelay);
    event votingPeriodSet(uint256 oldPeriod, uint256 newPeriod);
    event periodSet(uint128 _class, uint256 _period);

    address govStorageAddress;

    modifier onlyVetoOperator {
        require(
            msg.sender == IGovStorage(govStorageAddress).getVetoOperator(),
            "ProposalLogic: permission denied"
        );
        _;
    }

    modifier onlyGov {
        require(
            msg.sender == IGovStorage(govStorageAddress).getGovernanceAddress(),
            "ProposalLogic: Only Gov"
        );
        _;
    }

    constructor(
        address _govStorageAddress
    ) {
        govStorageAddress = _govStorageAddress;

        // to define during deployment
        _votingPeriod[0] = 2;
        _votingPeriod[1] = 2;
        _votingPeriod[2] = 2;
    }

    function calculateReward(
        uint128 _class,
        uint128 _nonce,
        address _tokenOwner
    ) external onlyGov returns(uint256 reward) {
        require(
            !hasBeenRewarded(_class, _nonce, _tokenOwner),
            "Gov: already rewarded"
        );
        
        _setUserHasBeenRewarded(_class, _nonce, _tokenOwner);

        uint256 benchmarkIR = IGovStorage(govStorageAddress).getBenchmarkIR();
        uint256 cdp = IGovStorage(govStorageAddress).cdpDGOVToDBIT();

        uint256 rewardRate = IInterestRates(
            IGovStorage(govStorageAddress).getInterestRatesContract()
        ).votingInterestRate(benchmarkIR, cdp);

        uint256 _reward;
        
        for(uint256 i = 1; i <= IGovStorage(govStorageAddress).getNumberOfVotingDays(_class); i++) {
            _reward += (1 ether * 1 ether) / IGovStorage(govStorageAddress).getTotalVoteTokenPerDay(_class, _nonce, i);
        }

        reward = getVoteWeight(_class, _nonce, _tokenOwner) * rewardRate * _reward / (36500 * 1 ether * 1 ether);
    }

    /**
    * @dev get the bnumber of days elapsed since the vote has started
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param day the current voting day
    */
    function _getVotingDay(uint128 _class, uint128 _nonce) internal view returns(uint256 day) {
        Proposal memory _proposal = IGovStorage(
            govStorageAddress
        ).getProposalStruct(_class, _nonce);

        uint256 duration = _proposal.startTime > block.timestamp ?
            0: block.timestamp - _proposal.startTime;
        
        day = (duration / IGovStorage(govStorageAddress).getNumberOfSecondInYear()) + 1;
    }

    function getUsersVoteData(
        uint128 _class,
        uint128 _nonce
    ) public view returns(UserVoteData[] memory) {
        return userVoteData[_class][_nonce];
    }

    function _getVotingPeriod(uint128 _class) internal view returns(uint256) {
        return _votingPeriod[_class];
    }

    function setVotingPeriod(uint128 _class, uint256 _period) public onlyVetoOperator {
        _setPeriod(_class, _period);
        emit periodSet(_class, _period);
    }

    function _setPeriod(uint128 _class, uint256 _period) private {
        _votingPeriod[_class] = _period;
    }

    function hasVoted(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) public view returns(bool voted) {
        voted = _proposalVotes[_class][_nonce].user[_account].hasVoted;
    }

    function numberOfVoteTokens(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) public view returns(uint256 amountTokens) {
        amountTokens = _proposalVotes[_class][_nonce].user[_account].weight;
    }

    function getProposalVotes(
        uint128 _class,
        uint128 _nonce
    ) public view returns(uint256 forVotes, uint256 againstVotes, uint256 abstainVotes) {
        ProposalVote storage proposalVote = _proposalVotes[_class][_nonce];

        (forVotes, againstVotes, abstainVotes) = 
        (
            proposalVote.forVotes,
            proposalVote.againstVotes,
            proposalVote.abstainVotes
        );
    }

    function getUserInfo(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) public view returns(
        bool,
        bool,
        uint256,
        uint256
    ) {
        return (
            _proposalVotes[_class][_nonce].user[_account].hasVoted,
            _proposalVotes[_class][_nonce].user[_account].hasBeenRewarded,
            _proposalVotes[_class][_nonce].user[_account].weight,
            _proposalVotes[_class][_nonce].user[_account].votingDay
        );
    }

    function _setUserHasBeenRewarded(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) private {
        require(
            _proposalVotes[_class][_nonce].user[_account].hasBeenRewarded == false,
            "VoteCounting: already rewarded"
        );

        address proposer = IGovStorage(
            govStorageAddress
        ).getProposalProposer(_class, _nonce);

        if(_account != proposer) {
            require(
                _proposalVotes[_class][_nonce].user[_account].hasVoted == true,
                "VoteCounting: you didn't vote"
            );        
        }

        _proposalVotes[_class][_nonce].user[_account].hasBeenRewarded = true;
    }

    function hasBeenRewarded(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) public view returns(bool) {
        return _proposalVotes[_class][_nonce].user[_account].hasBeenRewarded;
    }

    function getVoteWeight(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) public view returns(uint256) {
        return _proposalVotes[_class][_nonce].user[_account].weight;
    }

    function quorumReached(
        uint128 _class,
        uint128 _nonce
    ) public view returns(bool reached) {
        ProposalVote storage proposalVote = _proposalVotes[_class][_nonce];

        reached =  proposalVote.forVotes + proposalVote.abstainVotes >= _quorum(_class, _nonce);
    }

    function voteSucceeded(
        uint128 _class,
        uint128 _nonce
    ) public view returns(bool succeeded) {
        ProposalVote storage proposalVote = _proposalVotes[_class][_nonce];

        succeeded = proposalVote.forVotes > proposalVote.againstVotes;
    }

    function getVotingDay(
        uint128 _class,
        uint128 _nonce,
        address _voter
    ) public view returns(uint256) {
        return _proposalVotes[_class][_nonce].user[_voter].votingDay;
    }

    function vetoed(
        uint128 _class,
        uint128 _nonce
    ) public view returns(bool) {
        return _proposalVotes[_class][_nonce].vetoed;
    }

    function _quorum(
        uint128 _class,
        uint128 _nonce
    ) public view returns(uint256 proposalQuorum) {
        ProposalVote storage proposalVote = _proposalVotes[_class][_nonce];

        uint256 minApproval = IGovStorage(govStorageAddress).getClassQuorum(_class);

        proposalQuorum =  minApproval * (
            proposalVote.forVotes +
            proposalVote.againstVotes +
            proposalVote.abstainVotes
        ) / 100;
    }
}