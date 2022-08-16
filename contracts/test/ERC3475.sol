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

import "@debond-protocol/debond-erc3475-contracts/DebondERC3475.sol";

interface IUpdatable {
    function updateGovernance(
        address _governanceAddress
    ) external;

    function updateBank(
        address _bankAddress
    ) external;

    function updateBankBondManager(
        address _bankBondManagerAddress
    ) external;
}

contract ERC3475Executable is IUpdatable {
    address governance;
    address executable;
    address bank;
    address bankBondManager;

    modifier onlyExec {
        require(msg.sender == executable, "Bank: only exec");
        _;
    }
    
    function updateBank(
        address _bankAddress
    ) external onlyExec {
        bank = _bankAddress;
    }

    function updateBankBondManager(
        address _bankBondManagerAddress
    ) external onlyExec {
        bankBondManager = _bankBondManagerAddress;
    }

    function updateGovernance(
        address _governanceAddress
    ) external onlyExec {
        governance = _governanceAddress;
    }
}

contract ERC3475 is ERC3475Executable {
    constructor(
        address _governanceAddress,
        address _excutableAddress,
        address _bankAddress,
        address _bankBondManagerAddress
    ) {
        governance = _governanceAddress;
        executable = _excutableAddress;
        bank = _bankAddress;
        bankBondManager = _bankBondManagerAddress;
    }

    function getBankAddress() public view returns(address) {
        return bank;
    }

    function getGovernanceAddress() public view returns(address) {
        return governance;
    }

    function getBankBondManager() public view returns(address) {
        return bankBondManager;
    }

    function getExecutableAddress() public view returns(address) {
        return executable;
    }
}