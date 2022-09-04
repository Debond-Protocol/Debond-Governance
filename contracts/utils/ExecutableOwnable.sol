pragma solidity ^0.8.0;

import "../interfaces/IExecutableUpdatable.sol";

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

interface IActivable {

    function setIsActive(bool _isActive) external;
    function contractIsActive() external view returns(bool);
}

abstract contract ExecutableOwnable is IActivable, IExecutableUpdatable {
    address executableAddress;
    bool private isActive;

    constructor(address _executableAddress) {
        executableAddress = _executableAddress;
        isActive = true;
    }

    modifier onlyExecutable() {
        require(msg.sender == executableAddress, "GovernanceOwnable Restriction: Not authorised");
        _;
    }

    modifier _onlyIsActive() {
        require(isActive, "Contract Is Not Active");
        _;
    }

    function setIsActive(bool _isActive) external onlyExecutable {
        isActive = _isActive;
    }

    function contractIsActive() public view returns(bool) {
        return isActive;
    }

    function updateExecutableAddress(address _newExecutableAddress) external onlyExecutable {
        executableAddress = _newExecutableAddress;
    }

    function getExecutableAddress() external view returns(address) {
        return executableAddress;
    }
}
