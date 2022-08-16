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
        address _bankBondManagerAddress
    ) external;

    function updateOracle(
        address _oracleAddress
    ) external;
}

contract BankBondManagerExecutable is IUpdatable {
    address governance;
    address executable;
    address bank;
    address oracle;
    uint8 private _lock;

    modifier onlyExec {
        require(msg.sender == executable, "Bank: only exec");
        _;
    }

    function setBank(address _bankAddress) public {
        require(_lock == 0, "GovernanceMigrator: goStorage address already set");
        bank = _bankAddress;
        _lock == 1;
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

    function updateOracle(
        address _oracleAddress
    ) external onlyExec {
        oracle = _oracleAddress;
    }
}

contract BankBondManager is BankBondManagerExecutable {
    constructor(address _governanceAddress, address _executableAddress, address _oracle) {
        governance = _governanceAddress;
        executable = _executableAddress;
        oracle = _oracle;
    }

    function getGovernanceAddress() public view returns(address) {
        return governance;
    }

    function getBankAddress() public view returns(address) {
        return bank;
    }

    function getOracleAddress() public view returns(address) {
        return oracle;
    }
}