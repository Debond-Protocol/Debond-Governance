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

import "@debond-protocol/debond-exchange-contracts/Exchange.sol";

interface IUpdatable {
    function updateGovernance(
        address _governanceAddress
    ) external;

    function updateExecutable(
        address _executableAddress
    ) external;
}

contract ExchangeStorage is IUpdatable {
    address governance;
    address executable;

    modifier onlyExec {
        require(msg.sender == executable, "Exchange: only exec");
        _;
    }

    function updateGovernance(
        address _governanceAddress
    ) external onlyExec {
        governance = _governanceAddress;
    }

    function updateExecutable(
        address _executableAddress
    ) external onlyExec {
        executable = _executableAddress;
    }
}

contract ExchangeTest is Exchange, ExchangeStorage {
    constructor(
        address _exchangeStorageAddress,
        address _governanceAddress,
        address _executableAddress
    ) Exchange(_exchangeStorageAddress, _governanceAddress) {
        governance = _governanceAddress;
        executable = _executableAddress;
    }

    function getGovernanceAddress() public view returns(address) {
        return governance;
    }

    function getExecutableAddress() public view returns(address) {
        return executable;
    }
}