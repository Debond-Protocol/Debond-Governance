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

contract VoteCounting {
    struct UserVote {
        bool hasVoted;
        uint256 weight;
    }

    struct ProposalVote {
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        mapping(address => UserVote) userVote;
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
    */
    function hasVoted(
        uint256 _proposalId,
        address _account
    ) public view returns(bool) {
        return _proposalVotes[_proposalId].userVote[_account].hasVoted;
    }

    /**
    * @dev returns the number of vote tokens used by an account
    * @param _proposalId proposal id
    * @param _account voter account address
    */
    function numberOfVoteTokens(
        uint256 _proposalId,
        address _account
    ) public view returns(uint256) {
        return _proposalVotes[_proposalId].userVote[_account].weight;
    }

    function getProposalVotes(
        uint256 _proposalId
    ) public view returns(uint256, uint256, uint256) {
        ProposalVote storage proposalVote = _proposalVotes[_proposalId];

        return (
            proposalVote.forVotes,
            proposalVote.againstVotes,
            proposalVote.abstainVotes
        );
    }
}