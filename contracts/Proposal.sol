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

interface IGovernance {
    function updateBankContract(
        uint128 _class,
        uint128 _nonce,
        address _bank
    ) external returns(bool);
}

contract Proposal {
    address public governance;

    constructor (address _governance) {
        governance = _governance;
    }

    /**
    * @dev call the updateBankContract in Governance to update the bank contract address
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _bank new address of the bank contract
    */
    function updateBankContract(
        uint128 _class,
        uint128 _nonce,
        address _bank
    ) public returns(bool) {
        require(
            IGovernance(governance).updateBankContract(
                _class, _nonce, _bank
            ) == true
        );

        return true;
    }
}