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

import "@debond-protocol/debond-token-contracts/interfaces/IDebondToken.sol";
import "@debond-protocol/debond-apm-contracts/interfaces/IAPM.sol";

interface IUpdatable {
    function setBenchmarkIR(
        uint256 _newBenchmarkInterestRate
    ) external;

    function updateGovernance(
        address _governanceAddress
    ) external;

    function updateBankBondManager(
        address _bankBondManagerAddress
    ) external;

    function updateOracle(
        address _oracleAddress
    ) external;

    function updateExecutable(
        address _executableAddress
    ) external;
}

contract BankExecutable is IUpdatable {
    address governance;
    address executable;
    address bankBondManager;
    address apm;
    address oracle;
    uint256 benchmarkIR = 5 * 10**16;

    modifier onlyExec {
        require(msg.sender == executable, "Bank: only exec");
        _;
    }

    function setBenchmarkIR(
        uint256 _newBenchmarkInterestRate
    ) external onlyExec {
        benchmarkIR = _newBenchmarkInterestRate;
    }

    function updateGovernance(
        address _governanceAddress
    ) external onlyExec {
        governance = _governanceAddress;
    }

    function updateBankBondManager(
        address _bankBondManagerAddress
    ) external onlyExec {
        bankBondManager = _bankBondManagerAddress;
    }

    function updateOracle(
        address _oracleAddress
    ) external onlyExec {
        oracle = _oracleAddress;
    }

    function updateExecutable(
        address _executableAddress
    ) external onlyExec {
        executable = _executableAddress;
    }
}

contract Bank is BankExecutable {

    constructor(
        address _governance,
        address _executable,
        address _bankBondManager,
        address _oracle
    ) {
        governance = _governance;
        executable = _executable;
        bankBondManager = _bankBondManager;
        oracle = _oracle;
    }

    function mintCollateralisedSupply(address _token, address _to, uint256 _amount) public {
        IDebondToken(_token).mintCollateralisedSupply(_to, _amount);
    }

    function update(
        uint256 _amountA,
        uint256 _amountB,
        address _tokenA,
        address _tokenB
    ) external {
        IAPM(apm).updateWhenAddLiquidity(_amountA, _amountB, _tokenA, _tokenB);
    }

    function setAPMAddress(address _apm) public {
        apm = _apm;
    }

    function getBenchmarkIR() public view returns(uint256) {
        return benchmarkIR;
    }

    function getGovernanceAddress() public view returns(address) {
        return governance;
    }

    function getAPM() public view returns(address) {
        return apm;
    }

    function getOracleAddress() public view returns(address) {
        return oracle;
    }

    function getBankBondManager() public view returns(address) {
        return bankBondManager;
    }

    function getExecutableAddress() public view returns(address) {
        return executable;
    }
}