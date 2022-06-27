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

import ".././interfaces/INewGovernance.sol";

contract Proposal {
    address governance;

    constructor(address _governance) {
        governance = _governance;
    }

    function createProposal(
        uint128 _class,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    ) public {
        INewGovernance gov = INewGovernance(governance);
        require(gov.getGovernance() == governance, "Proposal: invalid Gov");

        gov.createProposal(
            _class,
            _targets,
            _values,
            _calldatas,
            _description
        );
    }

    function execute(
        uint128 _class,
        uint128 _nonce,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) public {
        INewGovernance gov = INewGovernance(governance);
        require(gov.getGovernance() == governance, "Proposal: invalid Gov");

        gov.executeProposal(
            _class,
            _nonce,
            _targets,
            _values,
            _calldatas,
            _descriptionHash
        );
    }
}