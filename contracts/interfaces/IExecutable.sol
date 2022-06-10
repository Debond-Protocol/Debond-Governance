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

    function updateBondContract(
        uint128 _proposalClass,
        uint128 _proposalNonce,
        address newBondAddress
    ) external returns(bool);

    function updateTokenContract(
        uint128 _proposalClass,
        uint128 _proposalNonce,
        uint256 newTokenClass,
        address newTokenAddress
    ) external returns(bool);

    // need to check if Fibonacci numbers are still used
    // if not then remove the last two inputs
    function createBondClass(
        uint128 poposalClass,
        uint128 proposalNonce,
        uint256 bondClass,
        string calldata bondSymbol,
        uint256 Fibonacci_number,
        uint256 Fibonacci_epoch
    ) external returns (bool);

    function transferTokenFromGovernance(
        uint128 poposalClass,
        uint128 proposalNonce,
        address _token,
        address _to,
        uint256 _amount
    ) external returns(bool);

    function claimFundForProposal(
        uint128 poposalClass,
        uint128 proposalNonce,
        address _to,
        uint256 dbitAmount,
        uint256 dgovAmount
    ) external returns(bool);

    function mintAllocationToken(
        address _to,
        uint256 dbitAmount,
        uint256 dgovAmount
    ) external returns(bool);

    function changeTeamAllocation(
        uint128 poposalClass,
        uint128 proposalNonce,
        address _to,
        uint256 dbitPPM,
        uint256 dgovPPM
    ) external returns(bool);

    function changeCommunityFundSize(
        uint128 poposalClass,
        uint128 proposalNonce,
        uint256 newDBITBudgetPPM,
        uint256 newDGOVBudgetPPM
    ) external returns(bool);
}