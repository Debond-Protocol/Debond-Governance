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
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@debond-protocol/debond-apm-contracts/interfaces/IAPM.sol";
import "../utils/ExecutableOwnable.sol";

contract APMTest is ExecutableOwnable {

    using SafeERC20 for IERC20;
    address bankAddress;

    constructor(
        address _executable
    ) ExecutableOwnable(_executable) {}

    function updateBankAddress(address _bankAddress) external onlyExecutable {
        require(_bankAddress != address(0), "APM: Address 0 given for Bank!");
        bankAddress = _bankAddress;
    }

    function removeLiquidity(address _to, address tokenAddress, uint amount) external onlyExecutable {
        IERC20(tokenAddress).safeTransfer(_to, amount);
    }
}
