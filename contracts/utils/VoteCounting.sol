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

import "../GovSharedStorage.sol";

contract VoteCounting is GovSharedStorage {
    struct User {
        bool hasVoted;
        bool hasBeenRewarded;
        uint256 weight;
        uint256 votingDay;
    }

    struct ProposalVote {
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 vetoApproval;
        mapping(address => User) user;
    }

    enum VoteType {
        For,
        Against,
        Abstain
    }

    mapping(uint128 => mapping(uint128 => ProposalVote)) internal _proposalVotes;

    /**
    * @dev check if an account has voted for a proposal
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _account voter account address
    * @param voted true if the account has already voted, false otherwise
    */
    function hasVoted(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) public view returns(bool voted) {
        voted = _proposalVotes[_class][_nonce].user[_account].hasVoted;
    }

    /**
    * @dev returns the number of vote tokens used by an account
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _account voter account address
    * @param amountTokens amount of vote tokens
    */
    function numberOfVoteTokens(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) public view returns(uint256 amountTokens) {
        amountTokens = _proposalVotes[_class][_nonce].user[_account].weight;
    }

    /**
    * @dev return number of votes of a proposal for each votre type
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param forVotes number or FOR votes
    * @param againstVotes number or AGAINST votes
    * @param abstainVotes number abstains
    */
    function getProposalVotes(
        uint128 _class,
        uint128 _nonce
    ) public view returns(uint256 forVotes, uint256 againstVotes, uint256 abstainVotes) {
        ProposalVote storage proposalVote = _proposalVotes[_class][_nonce];

        (forVotes, againstVotes, abstainVotes) = 
        (
            _proposalVotes[_class][_nonce].forVotes,
            proposalVote.againstVotes,
            proposalVote.abstainVotes
        );
    }

    /**
    * @dev return the User struct
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _account user account address
    */
    function getUserInfo(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) public view returns(User memory) {
        return _proposalVotes[_class][_nonce].user[_account];
    }

    /**
    * @dev check if the quorum has been reached
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param reached true if quorum has been reached, false otherwise
    */
    function _quorumReached(
        uint128 _class,
        uint128 _nonce
    ) internal view returns(bool reached) {
        ProposalVote storage proposalVote = _proposalVotes[_class][_nonce];

        reached =  proposalVote.forVotes + proposalVote.abstainVotes >= _quorum(_class, _nonce);
    }

    /**
    * @dev check if the vote is successful or not
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param succeeded true if FOR votes are greater than AGAINST vote
    */
    function _voteSucceeded(
        uint128 _class,
        uint128 _nonce
    ) internal view returns(bool succeeded) {
        ProposalVote storage proposalVote = _proposalVotes[_class][_nonce];

        succeeded = proposalVote.forVotes > proposalVote.againstVotes;
    }

    /**
    * @dev check if the veto approve or not
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param approved veto type: true if aggreed, else otherwise
    */
    function _vetoApproved(
        uint128 _class,
        uint128 _nonce
    ) internal view returns(bool approved) {
        uint256 veto = _proposalVotes[_class][_nonce].vetoApproval;

        approved = veto == 1 ? true : false;
    }

    /**
    * @dev update the user vote when he votes
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _account user account address
    * @param _vote user vote (0: For, 1: Against, 2: Abstain)
    * @param _weight the amount of vote tokens used to vote
    */
    function _countVote(
        uint128 _class,
        uint128 _nonce,
        address _account,
        uint8 _vote,
        uint256 _weight
    ) internal virtual {
        ProposalVote storage proposalVote = _proposalVotes[_class][_nonce];

        require(
            !proposalVote.user[_account].hasVoted,
            "VoteCounting: already voted"
        );

        proposalVote.user[_account].hasVoted = true;
        proposalVote.user[_account].weight = _weight;

        if (_vote == uint8(VoteType.For)) {
            proposalVote.forVotes += _weight;
        } else if (_vote == uint8(VoteType.Against)) {
            proposalVote.againstVotes += _weight;
        } else if (_vote == uint8(VoteType.Abstain)) {
            proposalVote.abstainVotes += _weight;
        } else {
            revert("VoteCounting: invalid vote");
        }
    }

    /**
    * @dev return the proposal quorum
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function _quorum(
        uint128 _class,
        uint128 _nonce
    ) internal view returns(uint256 quorum) {
        ProposalVote storage proposalVote = _proposalVotes[_class][_nonce];

        quorum =  proposalClassInfo[_class][1] * (
            proposalVote.forVotes +
            proposalVote.againstVotes +
            proposalVote.abstainVotes
        ) / 100;
    }
}