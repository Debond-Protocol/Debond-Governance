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

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./NewGovStorage.sol";
import "./interfaces/IVoteToken.sol";
import "./interfaces/IStakingDGOV.sol";
import "./interfaces/IGovernance.sol";
import "./interfaces/INewGovernance.sol";
import "./test/DBIT.sol";
import "./Pausable.sol";

contract NewGovernance is NewGovStorage, INewGovernance, ReentrancyGuard, Pausable {
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
    ) public returns(uint128 nonce, uint256 proposalId) {
        require(
            _targets.length == _values.length &&
            _values.length == _calldatas.length,
            "Gov: invalid proposal"
        );

        nonce = _generateNewNonce(_class);
        ProposalApproval approval = _approvalMode(_class);

        proposalId = _hashProposal(
            _class,
            nonce,
            _targets,
            _values,
            _calldatas,
            keccak256(bytes(_description))
        );

        uint256 _start = block.timestamp + voteStart;
        uint256 _end = _start + votePeriod;

        proposal[_class][nonce].id = proposalId;
        proposal[_class][nonce].startTime = _start;
        proposal[_class][nonce].endTime = _end;
        proposal[_class][nonce].approvalMode = approval;

        emit ProposalCreated(
            _class,
            nonce,
            proposalId,
            _start,
            _end,
            msg.sender,
            _targets,
            _values,
            _calldatas,
            _description,
            approval
        );
    }

    /**
    * @dev generate a new nonce for a given class
    * @param _class proposal class
    */
    function _generateNewNonce(uint128 _class) internal returns(uint128 nonce) {
        proposalClass[_class].nonce++;

        nonce = proposalClass[_class].nonce;
    }

    /**
    * @dev hash a proposal
    * @param _class proposal class
    * @param _targets array of target contracts
    * @param _values array of ether send
    * @param _calldatas array of calldata to be executed
    * @param _descriptionHash the hash of the proposal description
    */
    function _hashProposal(
        uint128 _class,
        uint128 _nonce,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) internal pure returns (uint256 proposalHash) {
        proposalHash = uint256(
            keccak256(
                abi.encode(
                    _class,
                    _nonce,
                    _targets,
                    _values,
                    _calldatas,
                    _descriptionHash
                )
            )
        );
    }

    /**
    * @dev set the vode stating time
    * @param _start time when the vote should start
    */
    function _setVoteStartTime(uint256 _start) internal {
        voteStart = _start;
    }

    /**
    * @dev set the vote ending time
    * @param _end time at when the vote should end
    */
    function _setVotePeriod(uint256 _end) internal {
        votePeriod = _end;
    }

    /**
    * @dev returns the proposal approval mode according to the proposal class
    * @param _class proposal class
    */
    function _approvalMode(
        uint128 _class
    ) internal pure returns(ProposalApproval unsassigned) {
        if (_class == 0 || _class == 1) {
            return ProposalApproval.Approve;
        }

        if (_class == 2) {
            return ProposalApproval.NoVote;
        }
    }

}