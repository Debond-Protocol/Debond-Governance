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

pragma solidity ^0.8.9;

/// @title interface of proposal factory
/// @notice Explain to an end user what this does
/// @dev Explain to a developer any extra details

interface IProposalFactory {
    enum InterestRateType {
        FixedRate,
        FloatingRate
    }

    function revokeProposal(
        uint128 _class,
        uint128 _nonce,
        uint128 revoke_proposal_class,
        uint128 revoke_proposal_nonce
    ) external;


    function addBondClass(
        uint256 newBondClass,
        uint256 proposal_class,
        uint256 proposal_nonce,
        string calldata symbol,
        InterestRateType interestRateType,
        address tokenAddress,
        uint256 periodTimestamp
    ) external;

    function setDBITAmountForOneVote(uint256 _dbitAmount) external  returns(bool);

    // function transferDBITAllocation(
    //     address _from,
    //     address _to,
    //     uint256 _amount,
    //     uint256 proposal_class,
    //     uint256 proposal_nonce
    // ) external;

    function pauseAll(
        uint256 proposal_class,
        uint256 proposal_nonce,
        bool setState
    ) external;

    function changeCommunityFundSize(
        uint128 _proposalClass,
        uint128 _proposalNonce,
        uint256 _newDBITBudget,
        uint256 _newDGOVBudget
    ) external returns (bool);

    function claimFundForProposal(
        uint128 _class,
        uint128 _proposalNonce,
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) external returns (bool);
   
    function updatePurchesableClasses(uint debondClassId, uint proposalClass, uint ProposalNonce ,  uint[] calldata purchaseClassId, bool[] calldata purchasable)   external;

    // function updateDebondBondContract(uint proposal_class, uint proposal_nonce, address newBondAddress ) external;

    // function updateDBITContract(uint proposal_class,uint proposal_nonce, address newDBITAddress ) external;

    // function updateDGOVContract(uint proposal_class,uint proposal_nonce, address newDBITAddress) external;

    // function updateExchangeContract(uint proposal_class,uint proposal_nonce, address newExchangeAddress) external;
}
