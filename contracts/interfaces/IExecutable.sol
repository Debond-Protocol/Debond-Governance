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

interface IExecutable {
    function createProposal(
        uint128 _proposalClass,
        address _address,
        uint256 _execution_nonce,
        uint256 _execution_interval
    ) external returns(bool);

    function revokeProposal(
        uint128 _proposalClass,
        uint128 _proposalNonce,
        uint256 revoke_class,
        uint256 revoke_nonce
    ) external returns(bool);

    function updateGovernanceContract(
        uint128 _proposalClass,
        uint128 _proposalNonce,
        address _newGovernanceAddress
    ) external returns(bool);

    function updateExchangeContract(
        uint128 _proposalClass,
        uint128 _proposalNonce,
        address newExchangeAddress
    ) external returns(bool);

    function updateBankContract(
        uint128 _proposalClass,
        uint128 _proposalNonce,
        address newBankAddress
    ) external returns(bool);

    // need to check if Fibonacci numbers are still used
    // if not then remove the last two inputs
    function createBondClass(
        uint128 poposalClass,
        uint128 proposalNonce,
        uint256 bondClass,
        uint256[] calldata classInfo,
        string[] calldata classInfoDescription
    ) external returns (bool);

    function transferToken(
        uint128 poposalClass,
        uint128 proposalNonce,
        address _token,
        address _to,
        uint256 _amount
    ) external returns(bool);

    function transferTokenFromAPM(
        uint128 poposalClass,
        uint128 proposalNonce,
        address _from,
        address _token,
        address _to,
        uint256 _amount
    ) external returns(bool);

    function mintAllocationToken(
        address _to,
        uint256 dbitAmount,
        uint256 dgovAmount
    ) external returns(bool);

    //change how much allocation an address can enjoy
    function changeTeamAllocation(
        uint128 poposalClass,
        uint128 proposalNonce,
        address _to,
        uint256 dbitPPM,
        uint256 dgovPPM
    ) external returns(bool);

    //change the percentage of token that can be minted as allocation, start from 10%,
    function changeCommunityFundSize(
        uint128 _poposalClass,
        uint128 _proposalNonce,
        uint256 _newDBITBudgetPPM,
        uint256 _newDGOVBudgetPPM
    ) external returns(bool);

    //Update benchmark intrest rate
    function updateBenchmarkInterestRate(
        uint128 _proposalClass,
        uint128 _proposalNonce,
        uint256 _newBenchmarkInterestRate
    ) external returns(bool);

    //update maximum supply of DGOV
    function updateDGOVMaxSupply(
        uint128 _proposalClass,
        uint128 _proposalNonce,
        uint256 _newDGOVMaxSupply
    ) external returns(bool);
}