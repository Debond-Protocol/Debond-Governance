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

import "./IGovSharedStorage.sol";

interface IProposalLogic is IGovSharedStorage {
    function cancelProposal(
        uint128 _class,
        uint128 _nonce
    ) external;

    function voteRequirement(
        uint128 _class,
        uint128 _nonce,
        address _tokenOwner,
        address _voter,
        uint256 _amountVoteTokens,
        uint256 _stakingCounter
    ) external;

    function unstakeDGOVandCalculateInterest(
        address _staker,
        uint256 _stakingCounter
    ) external returns(uint256 amountStaked, uint256 interest, uint256 duration);

    function calculateReward(
        uint128 _class,
        uint128 _nonce,
        address _tokenOwner
    ) external returns(uint256 reward);

    function unlockVoteTokens(
        uint128 _class,
        uint128 _nonce,
        address _tokenOwner
    ) external;

    function vote(
        uint128 _class,
        uint128 _nonce,
        address _voter,
        uint8 _userVote,
        uint256 _amountVoteTokens
    ) external;

    function proposalSetUp(
        uint128 _class,
        uint128 _nonce,
        address _proposer,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _title,
        bytes32 _descriptionHash
    ) external returns(uint256 start, uint256 end, ProposalApproval approval);
}