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

import "../utils/ExecutableOwnable.sol";


contract DebondERC3475Test is ExecutableOwnable {
    address bankAddress;
    address bankBondManagerAddress;

    constructor(
        address _excutableAddress
    ) ExecutableOwnable(_excutableAddress) {}

    function updateBankAddress(address _bankAddress) external onlyExecutable {
        bankAddress = _bankAddress;
    }

    function updateBondManagerAddress(address _bankBondManagerAddress) external onlyExecutable {
        bankBondManagerAddress = _bankBondManagerAddress;
    }

    function getBankAddress() external view returns(address) {
        return bankAddress;
    }

    function getBankBondManager() external view returns(address) {
        return bankBondManagerAddress;
    }
}
