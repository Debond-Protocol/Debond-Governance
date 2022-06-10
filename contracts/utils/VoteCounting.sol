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
        uint8 weight;
        uint256 votingDay;
    }

    struct ProposalVote {
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        mapping(address => User) user;
    }

    enum VoteType {
        For,
        Against,
        Abstain
    }

    mapping(uint256 => ProposalVote) internal _proposalVotes;

    /**
    * @dev check if an account has voted for a proposal
    * @param _proposalId proposal id
    * @param _account voter account address
    * @param voted true if the account has already voted, false otherwise
    */
    function hasVoted(
        uint256 _proposalId,
        address _account
    ) public view returns(bool voted) {
        voted = _proposalVotes[_proposalId].user[_account].hasVoted;
    }

    /**
    * @dev returns the number of vote tokens used by an account
    * @param _proposalId proposal id
    * @param _account voter account address
    * @param amountTokens amount of vote tokens
    */
    function numberOfVoteTokens(
        uint256 _proposalId,
        address _account
    ) public view returns(uint256 amountTokens) {
        amountTokens = _proposalVotes[_proposalId].user[_account].weight;
    }

    /**
    * @dev return number of votes of a proposal for each votre type
    * @param _proposalId proposal id
    * @param forVotes number or FOR votes
    * @param againstVotes number or AGAINST votes
    * @param abstainVotes number abstains
    */
    function getProposalVotes(
        uint256 _proposalId
    ) public view returns(uint256 forVotes, uint256 againstVotes, uint256 abstainVotes) {
        ProposalVote storage proposalVote = _proposalVotes[_proposalId];

        (forVotes, againstVotes, abstainVotes) = 
        (
            proposalVote.forVotes,
            proposalVote.againstVotes,
            proposalVote.abstainVotes
        );
    }

    /**
    * @dev check if the quorum has been reached
    * @param _proposalId proposal id
    * @param reached true if quorum has been reached, false otherwise
    */
    function _quorumReached(
        uint256 _proposalId
    ) internal view returns(bool reached) {
        ProposalVote storage proposalVote = _proposalVotes[_proposalId];

        reached = _quorum(_proposalId) <= proposalVote.forVotes + proposalVote.abstainVotes;
    }

    /**
    * @dev check if the vote is successful or not
    * @param _proposalId proposal id
    * @param succeeded true if FOR votes are greater than AGAINST vote
    */
    function _voteSucceeded(
        uint256 _proposalId
    ) internal view returns(bool succeeded) {
        ProposalVote storage proposalVote = _proposalVotes[_proposalId];

        succeeded = proposalVote.forVotes > proposalVote.againstVotes;
    } 

    /**
    * @dev update the user vote when he votes
    * @param _proposalId proposal id
    * @param _account user account address
    * @param _vote user vote (0: For, 1: Against, 2: Abstain)
    * @param _weight the amount of vote tokens used to vote
    */
    function _countVote(
        uint256 _proposalId,
        address _account,
        uint8 _vote,
        uint256 _votingDay,
        uint256 _weight
    ) internal virtual {
        ProposalVote storage proposalVote = _proposalVotes[_proposalId];

        require(
            !proposalVote.user[_account].hasVoted,
            "VoteCounting: already voted"
        );

        proposalVote.user[_account].hasVoted = true;

        if (_vote == uint8(VoteType.For)) {
            proposalVote.forVotes += _weight;
        } else if (_vote == uint8(VoteType.Against)) {
            proposalVote.againstVotes += _weight;
        } else if (_vote == uint8(VoteType.Abstain)) {
            proposalVote.abstainVotes += _weight;
        } else {
            revert("VoteCounting: invalid vote");
        }

        proposalVote.user[_account].votingDay = _votingDay;
        proposalVote.user[_account].weight = uint8(_weight);
    }

    function _quorum(
        uint256 _proposalId
    ) internal view returns(uint256 quorum) {
        uint128 class = proposalClass[_proposalId];

        ProposalVote storage proposalVote = _proposalVotes[_proposalId];

        quorum =  proposalClassInfo[class][1] * (
            proposalVote.forVotes +
            proposalVote.againstVotes +
            proposalVote.abstainVotes
        ) / 100;
    }
}