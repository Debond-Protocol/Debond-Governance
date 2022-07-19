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

import "./interfaces/IGovStorage.sol";
import "./interfaces/IExecutable.sol";

contract Executable is IExecutable {
    address public govStorageAddress;

    constructor(address _govStorageAddress) {
        govStorageAddress = _govStorageAddress;
    }

    function setGovStorageAddress(address _newGovStorageAddress) public {
        govStorageAddress = _newGovStorageAddress;
    }

    /**
    * @dev update the governance contract
    * @param _newGovernanceAddress new address for the Governance contract
    */
    function updateGovernanceContract(
        address _newGovernanceAddress
    ) public returns(bool) {
        IGovStorage(govStorageAddress).updateGovernanceContract(_newGovernanceAddress);

        return true;
    }

    /**
    * @dev update the exchange contract
    * @param _newExchangeAddress new address for the Exchange contract
    */
    function updateExchangeContract(
        address _newExchangeAddress
    ) public returns(bool) {
        IGovStorage(govStorageAddress).updateExchangeContract(_newExchangeAddress);

        return true;
    }

    /**
    * @dev update the bank contract
    * @param _newBankAddress new address for the Bank contract
    */
    function updateBankContract(
        address _newBankAddress
    ) public returns(bool) {
        IGovStorage(govStorageAddress).updateBankContract(_newBankAddress);

        return true;
    }

    /**
    * @dev update the benchmark interest rate
    * @param _newBenchmarkInterestRate new benchmark interest rate
    */
    function updateBenchmarkInterestRate(
        uint256 _newBenchmarkInterestRate
    ) public returns(bool) {
        IGovStorage(govStorageAddress).updateBenchmarkInterestRate(_newBenchmarkInterestRate);

        return true;
    }

    /**
    * @dev change the community fund size (DBIT, DGOV)
    * @param _newDBITBudgetPPM new DBIT budget for community
    * @param _newDGOVBudgetPPM new DGOV budget for community
    */
    function changeCommunityFundSize(
        uint256 _newDBITBudgetPPM,
        uint256 _newDGOVBudgetPPM
    ) public returns(bool) {
        IGovStorage(govStorageAddress).changeCommunityFundSize(_newDBITBudgetPPM, _newDGOVBudgetPPM);

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
        uint256 _newDGOVPPM
    ) public returns(bool) {
        IGovStorage(govStorageAddress).changeTeamAllocation(_to, _newDBITPPM, _newDGOVPPM);

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
        uint256 _amountDGOV
    ) public returns(bool) {
        IGovStorage(govStorageAddress).mintAllocatedToken(_to, _amountDBIT, _amountDGOV);

        return true;
    }

    /**
    * @dev claim fund for a proposal
    * @param _to address to transfer fund
    * @param _amountDBIT DBIT amount to transfer
    * @param _amountDGOV DGOV amount to transfer
    */
    function claimFundForProposal(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) public returns(bool) {
        IGovStorage(govStorageAddress).claimFundForProposal(_to, _amountDBIT, _amountDGOV);

        return true;
    }
}