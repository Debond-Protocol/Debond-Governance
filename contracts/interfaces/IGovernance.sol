pragma solidity ^0.8.0;

// SPDX-License-Identifier: apache 2.0
/*
    Copyright 2020 Sigmoid Foundation <info@SGM.finance>
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


interface IGovernance {
    /**
    * @dev emitted when new virtual `voteToken` tokens are created
    */
    event tokenMinted(address _user, uint256 _amount);

    /**
    * @dev emitted when new virtual `voteToken` tokens are burned
    */
    event tokenBurned(address _user, uint256 _amount);

    /**
    * @dev emitted when new virtual `voteToken` tokens is transfered
    */
    event voteTokenTransfered(address _from, address _to, uint256 _amount);
    
    /**
    * @dev emitted when a new proposal is created
    */
    event proposalRegistered(
        uint128 _class,
        uint128 _nonce,
        uint256 _endTime,
        address _contractAddress
    );

    /**
    * @dev emitted when a new proposal is revoked
    */
    event proposalRevoked(
        uint128 _class,
        uint128 _nonce
    );

    /**
    * @dev emitted when a new proposal is paused
    */
    event proposalPaused(
        uint128 _class,
        uint128 _nonce
    );

        /**
    * @dev emitted when a user vote
    */
    event userVoted(
        uint128 _class,
        uint128 _nonce,
        address _proposalContractAddress,
        uint256 _amountVoteTokens
    );

    /**
    * @dev emitted when vote tokens are redeemed
    */
    event voteTokenRedeemed(
        address _voter,
        address _to,
        uint128 _class,
        uint128 _nonce,
        address _contractAddress
    );

    /**
    * @dev register a proposal
    */
    function registerProposal(
        uint128 _class,
        address _owner,
        uint256 _endTime,
        uint256 _dbitRewards,
        address _contractAddress,
        bytes32 _proposalHash,
        uint256[] memory _dbitDistributedPerDay
    ) external;

    /**
    * @dev revoke a proposal
    */
    function revokeProposal(
        uint128 _class,
        uint128 _nonce
    ) external;

    /**
    * @dev redeem vote tokens for DBIT interests gained
    */
    function redeemVoteTokenForDBIT(
        address _voter,
        address _to,
        uint128 _class,
        uint128 _nonce,
        address _contractAddress
    ) external;
}