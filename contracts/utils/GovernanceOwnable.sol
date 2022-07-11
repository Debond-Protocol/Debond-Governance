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

import "../interfaces/IActivable.sol";
import "../interfaces/IGovernanceAddressUpdatable.sol";

contract GovernanceOwnable is IActivable {
    address governanceAddress;
    bool private isActive;

    constructor(address _governanceAddress) {
        governanceAddress = _governanceAddress;
        isActive = true;
    }

    modifier onlyGovernance() {
        require(msg.sender == governanceAddress, "Governance Restriction: Not allowed");
        _;
    }

    modifier _onlyIsActive() {
        require(isActive, "Contract Is Not Active");
        _;
    }

    function setIsActive(bool _isActive) external onlyGovernance {
        isActive = _isActive;
    }

    function contractIsActive() public view returns(bool) {
        return isActive;
    }
}
