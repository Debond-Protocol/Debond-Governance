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

interface INewGovernance {
    struct  Proposal {
        uint256 id;
        uint256 startTime;
        uint256 endTime;
        ProposalStatus status;
        ProposalApproval approvalMode;
    }

    enum ProposalStatus {
        Active,
        Canceled,
        Pending,
        Defeated,
        Succeeded,
        Executed
    }

    enum ProposalApproval {
        NoVote,
        Approve,
        VoteAndVeto
    }

        /**
     * @dev Emitted when a proposal is created.
     */
     event ProposalCreated(
        uint128 class,
        uint128 nonce,
        uint256 proposalId,
        uint256 startVoteTime,
        uint256 endVoteTime,
        address proposer,
        address[] targets,
        uint256[] values,
        bytes[] calldatas,
        string description,
        ProposalApproval approval
    );

    /**
    * @dev Emitted when a proposal is executed
    */
    event ProposalExecuted(uint256 proposalId);

    /**
    * @dev create a proposal onchain
    * @param _class proposal class
    * @param _targets array of target contracts
    * @param _values array of ether send
    * @param _calldatas array of calldata to be executed
    * @param _description proposal description
    */
    function createProposal(
        uint128 _class,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    ) external returns(uint128 nonce, uint256 proposalId);

    /**
    * @dev execute a proposal
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _targets array of target contracts
    * @param _values array of ether send
    * @param _calldatas array of calldata to be executed
    * @param _descriptionHash hash of the proposal description
    */
    function executeProposal(
        uint128 _class,
        uint128 _nonce,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) external returns(uint256 proposalId);

    /**
    * @dev return the governance address
    */
    function getGovernance() external view returns(address);
}