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

interface IUpdatable {
    function updateGovernance(
        address _governanceAddress
    ) external;

    function updateBank(
        address _bankAddress
    ) external;
}

contract BankDataExecutable is IUpdatable {
    address governance;
    address executable;
    address bank;

    modifier onlyExec {
        require(msg.sender == executable, "Bank: only exec");
        _;
    }

    function updateGovernance(
        address _governanceAddress
    ) external onlyExec {
        governance = _governanceAddress;
    }
    
    function updateBank(
        address _bankAddress
    ) external onlyExec {
        bank = _bankAddress;
    }
}

contract BankData is BankDataExecutable {
    constructor(
        address _governace,
        address _bank,
        address _executable
    ) {
        governance = _governace;
        bank = _bank;
        executable = _executable;
    }

    function getGovernanceAddress() public view returns(address) {
        return governance;
    }

    function getBankAddress() public view returns(address) {
        return bank;
    }
}