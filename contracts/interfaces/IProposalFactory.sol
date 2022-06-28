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

import "./IDebondBond.sol";

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


    /** sets the amount of DBIT  amt for one vote*/


    function setDBITAmountForOneVote(uint256 _dbitAmount) external  returns(bool);


    /** mints the allocated supply for the team based on the allocation / availablity of the DBIT/DGOV tokens 
    @param _class class of proposal 
    @param  _to recipient of the   tokens   (should be the _CSOAddress or address whitelisted by the governance to recieve the tokens). 
    @param    amountdGOV the amount of dGOV to be minted from quota.
    @param     amountDBIT are the amount of DBIT tokens to be minted.
     */

    function mintAllocation(uint _class , uint _nonce , address _to , uint amountdGOV , uint amountDBIT ) external;



    /**
    @dev adds the bond class .
    @param newBondClass is the new numer of the ERC20 based token class 
    @param _class is the proposal class proposing the execution. 
    @param _nonce    is hte nonce of proposal.
    @param  symbol is the string symbol representing the bond name (similar to the underlying ERC20 token).  
    @param interestRateType defines the type of bonds that are issued in this class (Fixed/floating rate).
    @param tokenAddress is the underlying ERC20 token details.
    @param  periodTimestamp defines the maturity period of the bonds in this class .
     */
    function addBondClass(
        uint256 newBondClass,
        uint256 _class,
        uint256 _nonce,
        string memory symbol,
        IDebondBond.InterestRateType interestRateType,
        address tokenAddress,
        uint256 periodTimestamp
    ) external;

/**
 function addBondClass(uint newBondClass , uint _class, uint _nonce, string memory symbol , IDebondBond.InterestRateType interestRateType , address tokenAddress , uint periodTimestamp)  external

*/




   
    /** stops the functionality of all the contracts by the  emergency proposal
    @dev  (called only by the higher class > 2).
    * proposal_class and _nonce are the details of proposal
    * setState is the final state (false to pause and true for unpause).
    *
     */
    function pauseAll(
        uint256 _class,
        uint256 _nonce,
        bool setState
    ) external;


    /**
    * @dev change the team allocation for both tokens 
    * @notice we cna set more than the amount fo the DBIT / dGOV _AllocatedSupply.
    * @param _class class of the proposal
    * @param _proposalNonce cnonce of the proposal
    * @param _to the address that should receive the allocation tokens
    * @param _newDbitPPM the new DBIT allocation
    * @param _newDgovPPM the new DGOV allocation
    */

     function changeTeamAllocation(
        uint128 _class,
        uint128 _proposalNonce,
        address _to,
        uint256 _newDbitPPM,
        uint256 _newDgovPPM
    )  external returns(bool) ;





     /**
    * @dev change the community fund size (DBIT, DGOV) that is possible by the proposal only.
    * @param _class class of the proposal
    * @param _nonce nonce of the proposal
    * @param _newDBITBudget new DBIT budget for community 
    * @param _newDGOVBudget new DGOV budget for community
    */



    function changeCommunityFundSize(
        uint128 _class,
        uint128 _nonce,
        uint256 _newDBITBudget,
        uint256 _newDGOVBudget
    ) external returns (bool);
   

    /**
    * @dev for creation of the new class of proposal.
    * @notice should be having the proposalApproval from the architectVeto.
    * @param _newProposalClass number of the new proposal class.
    * @param proposal_class is the proposal class which proposes the changes 
    * @param proposal_nonce is the nonce of the proposal.
    * @param _class the actual proposal class needed to be created.
    * @param _timelock is the time period for which the dGOV is reserved.
    * @param _minimumApproval is the minimum Voter % required to be passed the proposal with the same class and nonce. (defined in the checkProposal()).
    * @param _minimumVote  is the minimum Vote tokens needed for passing the proposal.
    * @param _architectVeto is  boolean to define whether these class of  proposals (with different nonces ) will be needing the architectVeto in their approval. 
    */



    function addProposalClass(
        uint256 _newProposalClass,
        uint256 proposal_class,
        uint256 proposal_nonce,
        uint _class,
        uint _timelock, 
        uint _minimumApproval, 
        uint _minimumVote, 
        bool _architectVeto, 
        uint _maximumExecutionTime, 
        uint _minimumExecutionTime
    ) external returns (bool);





    /** 
    * @dev allowing an proposal to activate / deactivate the purchaseable classes.
    * @notice not to be executed before insuring that corresponding APM liquidity is disbursed (ie only to be used in emergency of having an attack).
    * @param debondClassId is the classId of the debond asset  that needs to be associated (for not D/BIT is 0 and D/BOND is 1).
    * @param proposalClass class of the proposal introducing this function.
    * @param ProposalNonce nonce of the proposal introducing this function.
    * @param purchaseClassId is the array of the potential other ERC20 assets that needed to be paired for APM liquidity addition.
    * @param purchasable bool array to define whether debondClassId <> purchaseClasId{i} needs to be paired or not.
    */
    
    
    function updatePurchesableClasses(uint debondClassId, uint proposalClass, uint ProposalNonce ,  uint[] calldata purchaseClassId, bool[] calldata purchasable)   external;

    /**
    * @dev claim fund for a proposal 
    * @notice ( called by the D/Bond team for allocation  parameter settings)
    * @dev : should need 1.  classId > 2  2. and specific voting approval percentage. and approvalMode of the ArchitectVeto.
    * @param _class class of the proposal
    * @param _proposalNonce nonce of the proposal
    * @param _to address to transfer fund
    * @param _amountDBIT DBIT amount to transfer
    * @param _amountDGOV DGOV amount to transfer
    */
    function claimFundForProposal(
        uint128 _class,
        uint128 _proposalNonce,
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) external   returns(bool);

/** for setting max supply of dGOV if needed to be changed
@param _maxSupplyDGOV is the max supply of DGOV.
@notice that for the proposal the require class needed > 2 with veto status and approvalMode is canApprove.

 */

      
function setDovVMaxSupply(uint _maxSupplyDGOV) external returns(bool); 


/**
setting  benchmark rate of interest for calculation of the redemption of bond .
@param proposalClass is class of proposal.
@param proposalNonce is the nonce corresponding to given proposal.
 */


function setBenchmarkInterestRate(uint proposalClass , uint proposalNonce , uint _newRate) external;

/**
updating the token contracts

*/

function updateTokenContract(uint256 poposal_class, uint256 proposal_nonce, uint256 new_token_class, address new_token_address) external  returns(bool);




 function createBondClass(uint256 poposal_class, uint256 proposal_nonce, uint256 bond_class, string memory bond_symbol, uint256 Fibonacci_number, uint256 Fibonacci_epoch) external  returns (bool);


}
