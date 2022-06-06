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

pragma solidity ^0.8.9;

import "../interfaces/IGovernance.sol";
import "../interfaces/IProposalFactory.sol";

import "debond-bank/contracts/interfaces/IData.sol";

/// @title  proposal template 
/// @notice this contract is to be deployed before creation of the proposal instance , and then supplied in createProposal() in governance.
/// @dev Explain to a developer any extra details

contract FakeProposal {
    address public _vetoOperator;
    address public governance;
    address public dataAddress;
    IProposalFactory proposalFactory;
    
    constructor( 
        address veto,
        address governanceAddress,
        address _dataAddress
    ) {
        _vetoOperator = veto;
        governance = governanceAddress;
        dataAddress = _dataAddress;
        proposalFactory = IProposalFactory(governanceAddress);
    }

    modifier onlyGovContract() {
        require(msg.sender == _vetoOperator, "ERR_ONLY_ADMIN");
        _;
    }

    /**BANK OPERATIONS  */
    function AddNewBondClass(
        uint256 newClassId,
        uint _class , uint _nonce,
        string memory _symbol,
        IProposalFactory.InterestRateType interestRateType,
        address tokenAddress,
        uint256 periodTimestamp
    ) public  returns(bool) {
        proposalFactory.addClass(
            newClassId,_class,_nonce,
            _symbol,
            interestRateType,
            tokenAddress,
            periodTimestamp
        );
    return(true);
    // }
    // function updateBankContract(uint256 proposal_class, uint256 proposal_nonce, address new_bank_address) public  returns(bool){
    //    proposalFactory.setBankContract(new_bank_address , proposal_class,proposal_nonce);
    //    return(true);
    // }
    // /**
    // this function allows to update the  bond  token pairs that can be bought on the exchange.
    //  */
    // function updatePurchasableClass(uint debondClassId, uint _class , uint _nonce, uint[] calldata purchaseClassId, bool purchasable)  external {
    //    proposalFactory.updatePurchesableClasses(debondClassId, _class, _nonce, purchaseClassId, purchasable);
    //     return(true);
    // }

}
