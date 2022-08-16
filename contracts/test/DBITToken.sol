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

import "@debond-protocol/debond-token-contracts/DBIT.sol";

interface IUpdatable {
    function updateGovernance(
        address _governanceAddress
    ) external;

    function updateBank(
        address _bankAddress
    ) external;

    function updateAirdrop(
        address _airdropAddress
    ) external;
}

contract DBITExecutable is IUpdatable {
    address governance;
    address executable;
    address bank;
    address airdrop;

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

    function updateAirdrop(
        address _airdropAddress
    ) external onlyExec {
        airdrop = _airdropAddress;
    }
}

contract DBITToken is DBIT, DBITExecutable {
    constructor(
        address _governace,
        address _bank,
        address _airdrop,
        address _exchange,
        address _executable
    ) DBIT(_governace, _bank, _airdrop, _exchange) {
        governance = _governace;
        bank = _bank;
        executable = _executable;
        airdrop = _airdrop;
    }

    function getBankAddress() public view returns(address) {
        return bank;
    }

    function getAirdropAddress() public view returns(address) {
        return airdrop;
    }
}