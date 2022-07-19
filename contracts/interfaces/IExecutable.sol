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

interface IExecutable {
    // update the bank contract
    function updateGovernanceContract(
        address _newGovernanceAddress
    ) external returns(bool);

    // update the exchange contract
    function updateExchangeContract(
        address _newExchangeAddress
    ) external returns(bool);

    // update the bank contract
    function updateBankContract(
        address _newBankAddress
    ) external returns(bool);

    //Update benchmark intrest rate
    function updateBenchmarkInterestRate(
        uint256 _newBenchmarkInterestRate
    ) external returns(bool);

    // change the community fund size
    function changeCommunityFundSize(
        uint256 _newDBITBudgetPPM,
        uint256 _newDGOVBudgetPPM
    ) external returns(bool);

    // change the team allocation
    function changeTeamAllocation(
        address _to,
        uint256 _newDBITPPM,
        uint256 _newDGOVPPM
    ) external returns(bool);

    // mint allocated tokens
    function mintAllocatedToken(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) external returns(bool);

    // claim fund for proposal
    function claimFundForProposal(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) external returns(bool);
}