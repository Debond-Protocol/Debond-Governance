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
import "./utils/VoteCounting.sol";
import "./interfaces/IVoteToken.sol";
import "./interfaces/IStakingDGOV.sol";
import "./interfaces/IGovernance.sol";
import "./interfaces/INewGovernance.sol";
import "./test/DBIT.sol";
import "./Pausable.sol";

/**
* @author Samuel Gwlanold Edoumou (Debond Organization)
*/
contract NewGovernance is NewGovStorage, VoteCounting, ReentrancyGuard, Pausable {
    /**
    * @dev see {INewGovernance} for description
    * @param _class proposal class
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

        proposalClass[proposalId] = _class;

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
    * @dev execute a proposal
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function executeProposal(
        uint128 _class,
        uint128 _nonce,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) public returns(uint256 proposalId) {
        proposalId = _hashProposal(
            _class,
            _nonce,
            _targets,
            _values,
            _calldatas,
            _descriptionHash
        );

        ProposalStatus status = getProposalStatus(
            _class,
            _nonce,
            proposalId
        );

        require(
            status == ProposalStatus.Succeeded,
            "Gov: proposal not successful"
        );

        proposal[_class][_nonce].status = ProposalStatus.Executed;

        emit ProposalExecuted(proposalId);

        _execute(_targets, _values, _calldatas);
    }
    
    /**
    * @dev internal execution mechanism
    */
    function _execute(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas
    ) internal virtual {
        string memory errorMessage = "Gov: call reverted without message";

        for (uint256 i = 0; i < _targets.length; i++) {
            (
                bool success,
                bytes memory data
            ) = _targets[i].call{value: _values[i]}(_calldatas[i]);

            Address.verifyCallResult(success, data, errorMessage);
        }
    }

    /**
    * @dev vote for a proposal
    */
    function vote(
        uint128 _class,
        uint128 _nonce,
        uint8 _userVote,
        uint256 _amountVoteTokens
    ) public returns(uint256) {
        address voter = _msgSender();

        return _vote(_class, _nonce, voter, _userVote, _amountVoteTokens);
    }

    function _vote(
        uint128 _class,
        uint128 _nonce,
        address _voter,
        uint8 _userVote,
        uint256 _amountVoteTokens
    ) internal returns(uint256 amountOfVoteTokens) {
        Proposal memory _proposal = proposal[_class][_nonce];
        require(
            getProposalStatus(_class, _nonce, _proposal.id) == ProposalStatus.Active,
            "Gov: vote not active"
        );

        _countVote(_proposal.id, _voter, _userVote, _amountVoteTokens);

        amountOfVoteTokens = _amountVoteTokens;
    }

    /**
    * @dev return the proposal status
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _id proposal id
    */
    function getProposalStatus(
        uint128 _class,
        uint128 _nonce,
        uint256 _id
    ) public view returns(ProposalStatus unassigned) {
        Proposal memory _proposal = proposal[_class][_nonce];
        require(_proposal.id == _id, "Gov: invalid proposal");

        if (_proposal.status == ProposalStatus.Canceled) {
            return ProposalStatus.Canceled;
        }

        if (_proposal.status == ProposalStatus.Executed) {
            return ProposalStatus.Executed;
        }

        if (_proposal.startTime >= block.timestamp) {
            return ProposalStatus.Pending;
        }

        if (_proposal.endTime >= block.timestamp) {
            return ProposalStatus.Active;
        }

        if (_quorumReached(_proposal.id) && _voteSucceeded(_proposal.id)) {
            return ProposalStatus.Succeeded;
        } else {
            return ProposalStatus.Defeated;
        }
    }

    /**
    * @dev set the vote quorum for a given class
    * @param _class proposal class
    * @param _quorum the vote quorum
    */
    function setProposalQuorum(
        uint128 _class,
        uint256 _quorum
    ) public onlyDebondOperator {
        _proposalClassInfo[_class][1] = _quorum;
    }

    /**
    * @dev get the quorum for a given proposal class
    * @param _proposalId proposal id
    */
    function getProposalQuorum(uint256 _proposalId) public view returns(uint256) {
        return proposalQuorum[proposalClass[_proposalId]];
    }

    /**
    * @dev generate a new nonce for a given class
    * @param _class proposal class
    */
    function _generateNewNonce(uint128 _class) internal returns(uint128 nonce) {
        proposalNonce[_class].nonce++;

        nonce = proposalNonce[_class].nonce;
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
    function _setVoteStartTime(uint256 _start) public onlyDebondOperator {
        voteStart = _start;
    }

    /**
    * @dev set the vote ending time
    * @param _end time at when the vote should end
    */
    function _setVotePeriod(uint256 _end) public onlyDebondOperator {
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

    /**
    * @dev return the governance contract address
    */
    function getGovernance() public view returns(address) {
        return governance;
    }

}