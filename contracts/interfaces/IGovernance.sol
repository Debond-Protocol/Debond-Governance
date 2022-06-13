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

import "./IGovStorage.sol";


// @dev defines the functions of governance , which orchestrates the functionality of proposal creation , voting and deterction of results to get results.
// ref from openzeppelin.
interface IGovernance {
    /**
    @dev emits after the creation of  proposal.    
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
    * @dev emitted when a proposal is paused
    */
    event proposalPaused(
        uint128 _class,
        uint128 _nonce
    );

    /**
    * @dev emitted when a proposal is unpaused
    */
    event proposalUnpaused(
        uint128 _class,
        uint128 _nonce
    );

    /**
    * @dev emitted when a proposal is successfully voted
    */
    event proposalEnded(
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
    @dev emitted during the voting of the proposal via signature.
     */
    event userVotedBySig( uint128 _class, uint128 _nonce,address  _proposalContractAddress, uint256 _amountVoteTokens,bytes32 signatory );
    
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
    * @dev registers a proposal by storing the proposal contract details into gov storage and setting the status.
    **/
    function registerProposal(
        uint128 _class,
        uint128 _nonce,
        address _owner,
        uint256 _endTime,
        uint256 _dbitRewards,
        address _contractAddress,
        uint256[] calldata _dbitDistributedPerDay
    ) external;

    /**
    * @dev pause a proposal 
    * @notice can only be paused by the proposal creator or governance 
    */
    function pauseProposal(
        uint128 _class,
        uint128 _nonce
    ) external; 

    /**
    * @dev  unpauses the proposal contract
    * @notice can be unpaused by the governance. .
     */
    function unpauseProposal(
        uint128 _class,
        uint128 _nonce
    ) external ;

    /**
    * @dev sets  the  proposal  status (used  by debondOperator if the given proposal has the ProposalApprove.CanVeto defined).
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param Status is the  choice by the debondOperator (can only be Approve or rejected.)
    
     */

    function approvalProposal(
        uint128 _class,
        uint128 _nonce,
        IGovStorage.ProposalStatus  Status // 
    ) external;


    // function revokeProposal(
    //    uint128 _class,
    //     uint128 _nonce,
    //     uint128 revoking_class,
    //     uint128 revoking_nonce
    // ) external ;

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


    /**
    @dev voting the appliation 
     */

     function Vote(
        address _voter,
        uint128 _class,
        uint128 _nonce,
        address _proposalContractAddress,
        IGovStorage.VoteChoice _userVote,
        uint256 _amountVoteTokens
    ) external;


}