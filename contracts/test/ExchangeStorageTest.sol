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

import "@debond-protocol/debond-exchange-contracts/ExchangeStorage.sol";

interface IUpdatable {
    function updateGovernance(
        address _governanceAddress
    ) external;

    function updateExchange(
        address _exchangeAddress
    ) external;

    function updateExecutable(
        address _executableAddress
    ) external;
}

contract ExchangeStorageExecutable is IUpdatable {
    address governance;
    address exchange;
    address executable;
    uint8 private _lock;

    modifier onlyExec {
        require(msg.sender == executable, "Exchange: only exec");
        _;
    }

    function setExchange(address _exchangeAddress) public {
        require(_lock == 0, "ExchangeStorage: goStorage address already set");
        exchange = _exchangeAddress;
        _lock == 1;
    }
    
    function updateGovernance(
        address _governanceAddress
    ) external onlyExec {
        governance = _governanceAddress;
    }
    
    function updateExchange(
        address _exchangeAddress
    ) external onlyExec {
        exchange = _exchangeAddress;
    }

    function updateExecutable(
        address _executableAddress
    ) external onlyExec {
        executable = _executableAddress;
    }
}

contract ExchangeStorageTest is ExchangeStorage, ExchangeStorageExecutable {
    constructor(address _governance, address _executable) ExchangeStorage(_governance) {
        governance = _governance;
        executable = _executable;
    }

    function getGovernanceAddress() public view returns(address) {
        return governance;
    }

    function getExchangeAddress() external view returns(address) {
        return exchange;
    }

    function getExecutableAddress() public view returns(address) {
        return executable;
    }
}