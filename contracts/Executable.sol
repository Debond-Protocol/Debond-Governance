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
import "@openzeppelin/contracts/token/ERC20/IERC20.sol"; 
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
    * @dev set gov storage address
    */
    function setGovStorageAddress(
        address _newGovStorageAddress
    ) public onlyDebondOperator {
        require(
            _newGovStorageAddress != address(0), "Executable: zero address"
        );

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
        require(
            _newGovernanceAddress != address(0), "Executable: zero address"
        );

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
        require(
            _newExchangeAddress != address(0), "Executable: zero address"
        );

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
        require(
            _newBankAddress != address(0), "Executable: zero address"
        );

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
        require(_proposalClass < 1, "Executable: class not valid");

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
        require(_to != address(0), "Executable: zero address");

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
        require(_to != address(0), "Executable: zero address");

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
        require(_to != address(0), "Executable: zero address");

        IGovStorage(govStorageAddress).claimFundForProposal(_to, _amountDBIT, _amountDGOV);

        return true;
    }

    /**
    * @dev transfer tokens from Governance to address `to`
    * @param _proposalClass proposal class
    * @param _proposalNonce proposal nonce
    * @param _tokenContract address of the token to transfer
    * @param _proposer the proposer address
    * @param _to the receiver address of tokens
    * @param _amount the amount of tokens to transfer
    */
    function transferTokenFromGovernance(
        uint128 _proposalClass,
        uint128 _proposalNonce,
        address _tokenContract,
        address _proposer,
        address _to,
        uint256 _amount
    ) public returns(bool) {
        require(_proposalClass <= 2, "Executable: class not valid");

        Proposal memory proposal = IGovStorage(
            govStorageAddress
        ).getProposalStruct(_proposalClass, _proposalNonce);

        require(_proposer == proposal.proposer, "GovStorage: permission denied");

        require(IERC20(_tokenContract).transfer(_to, _amount));

        return true;
    }
}