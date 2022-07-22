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

import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IGovStorage.sol";
import "./interfaces/IGovSharedStorage.sol";
import "./interfaces/IVoteCounting.sol";
import "./interfaces/IExecutable.sol";

contract Executable is IExecutable, IGovSharedStorage {
    address public govStorageAddress;
    address public voteCountingAddress;

    modifier onlyDebondOperator {
        require(
            msg.sender == IGovStorage(govStorageAddress).getDebondOperator(),
            "Executable: permission denied"
        );
        _;
    }

    modifier onlyDebondExecutor(address _executor) {
        require(
            _executor == IGovStorage(govStorageAddress).getDebondTeamAddress() ||
            _executor == IGovStorage(govStorageAddress).getDebondOperator(),
            "Gov: can't execute this task"
        );
        _;
    }

    constructor(
        address _govStorageAddress,
        address _voteCountingAddress
    ) {
        govStorageAddress = _govStorageAddress;
        voteCountingAddress = _voteCountingAddress;
    }

    /**
    * @dev execute a proposal
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function executeProposal(
        uint128 _class,
        uint128 _nonce
    ) public returns(bool) {
        require(_class >= 0 && _nonce > 0, "Gov: invalid proposal");

        Proposal memory proposal = IGovStorage(
            govStorageAddress
        ).getProposalStruct(_class, _nonce);
        
        require(
            msg.sender == proposal.proposer,
            "Gov: permission denied"
        );
        
        ProposalStatus status = _getProposalStatus(
            _class,
            _nonce
        );

        require(
            status == ProposalStatus.Succeeded,
            "Gov: proposal not successful"
        );
        
        IGovStorage(
            govStorageAddress
        ).setProposalStatus(_class, _nonce, ProposalStatus.Executed);

        emit ProposalExecuted(_class, _nonce);

        _execute(proposal.targets, proposal.values, proposal.calldatas);
        
        return true;
    }

    /**
    * @dev internal execution mechanism
    * @param _targets array of contract to interact with
    * @param _values array contraining ethers to send (can be array of zeros)
    * @param _calldatas array of encoded functions
    */
    function _execute(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas
    ) internal virtual {
        string memory errorMessage = "Executable: execute proposal reverted";
        
        for (uint256 i = 0; i < _targets.length; i++) {
            (
                bool success,
                bytes memory data
            ) = _targets[i].call{value: _values[i]}(_calldatas[i]);

            Address.verifyCallResult(success, data, errorMessage);
        }
    }

    /**
    * @dev return the proposal status
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function _getProposalStatus(
        uint128 _class,
        uint128 _nonce
    ) internal view returns(ProposalStatus unassigned) {
        Proposal memory proposal = IGovStorage(govStorageAddress).getProposalStruct(_class, _nonce);
        
        if (proposal.status == ProposalStatus.Canceled) {
            return ProposalStatus.Canceled;
        }

        if (proposal.status == ProposalStatus.Executed) {
            return ProposalStatus.Executed;
        }

        if (block.timestamp <= proposal.startTime) {
            return ProposalStatus.Pending;
        }

        if (block.timestamp <= proposal.endTime) {
            return ProposalStatus.Active;
        }

        if (_class == 2) {
            if (
                IVoteCounting(voteCountingAddress).quorumReached(_class, _nonce) && 
                IVoteCounting(voteCountingAddress).voteSucceeded(_class, _nonce)
            ) {
                return ProposalStatus.Succeeded;
            } else {
                return ProposalStatus.Defeated;
            }
        } else {
            if (IVoteCounting(voteCountingAddress).vetoApproved(_class, _nonce)) {
                return ProposalStatus.Succeeded;
            } else {
                return ProposalStatus.Defeated;
            }
        }
    }

    /**
    * @dev set gov storage address
    */
    function setGovStorageAddress(address _newGovStorageAddress) public onlyDebondOperator {
        govStorageAddress = _newGovStorageAddress;
    }

    /**********************************************************************************
    *         Executable functions (executed only after a proposal has passed)
    **********************************************************************************/

    /**
    * @dev update the governance contract
    * @param _newGovernanceAddress new address for the Governance contract
    */
    function updateGovernanceContract(
        address _newGovernanceAddress,
        address _executor
    ) public onlyDebondExecutor(_executor) returns(bool) {
        IGovStorage(govStorageAddress).updateGovernanceContract(_newGovernanceAddress, _executor);

        return true;
    }

    /**
    * @dev update the exchange contract
    * @param _newExchangeAddress new address for the Exchange contract
    */
    function updateExchangeContract(
        address _newExchangeAddress,
        address _executor
    ) public onlyDebondExecutor(_executor) returns(bool) {
        IGovStorage(govStorageAddress).updateExchangeContract(_newExchangeAddress, _executor);

        return true;
    }

    /**
    * @dev update the bank contract
    * @param _newBankAddress new address for the Bank contract
    */
    function updateBankContract(
        address _newBankAddress,
        address _executor
    ) public onlyDebondExecutor(_executor) returns(bool) {
        IGovStorage(govStorageAddress).updateBankContract(_newBankAddress, _executor);

        return true;
    }

    /**
    * @dev update the benchmark interest rate
    * @param _newBenchmarkInterestRate new benchmark interest rate
    */
    function updateBenchmarkInterestRate(
        uint256 _newBenchmarkInterestRate,
        address _executor
    ) public onlyDebondExecutor(_executor) returns(bool) {
        IGovStorage(govStorageAddress).updateBenchmarkIR(_newBenchmarkInterestRate, _executor);

        return true;
    }

    /**
    * @dev change the community fund size (DBIT, DGOV)
    * @param _newDBITBudgetPPM new DBIT budget for community
    * @param _newDGOVBudgetPPM new DGOV budget for community
    */
    function changeCommunityFundSize(
        uint128 _proposalClass,
        uint256 _newDBITBudgetPPM,
        uint256 _newDGOVBudgetPPM,
        address _executor
    ) public onlyDebondExecutor(_executor) returns(bool) {
        require(_proposalClass < 1, "Gov: class not valid");

        IGovStorage(govStorageAddress).changeCommunityFundSize(_newDBITBudgetPPM, _newDGOVBudgetPPM, _executor);

        return true;
    }

    /**
    * @dev change the team allocation - (DBIT, DGOV)
    * @param _to the address that should receive the allocation tokens
    * @param _newDBITPPM the new DBIT allocation
    * @param _newDGOVPPM the new DGOV allocation
    */
    function changeTeamAllocation(
        address _to,
        uint256 _newDBITPPM,
        uint256 _newDGOVPPM,
        address _executor
    ) public onlyDebondExecutor(_executor) returns(bool) {
        IGovStorage(govStorageAddress).changeTeamAllocation(_to, _newDBITPPM, _newDGOVPPM, _executor);

        return true;
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
        uint256 _amountDGOV,
        address _executor
    ) public onlyDebondExecutor(_executor) returns(bool) {
        IGovStorage(govStorageAddress).mintAllocatedToken(_to, _amountDBIT, _amountDGOV, _executor);

        return true;
    }

    /**
    * @dev claim fund for a proposal
    * @param _to address to transfer fund
    * @param _amountDBIT DBIT amount to transfer
    * @param _amountDGOV DGOV amount to transfer
    */
    function claimFundForProposal(
        uint128 _proposalClass,
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) public returns(bool) {
        require(_proposalClass <= 2, "Gov: class not valid");

        IGovStorage(govStorageAddress).claimFundForProposal(_to, _amountDBIT, _amountDGOV);

        return true;
    }
}