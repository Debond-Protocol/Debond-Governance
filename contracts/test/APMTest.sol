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

contract APMTest is IAPM, ExecutableOwnable {

    using SafeERC20 for IERC20;
    address bankAddress;

    constructor(
        address _bankAddress,
        address _executable
    ) ExecutableOwnable(_executable) {
        bankAddress == _bankAddress;
    }

    function updateBankAddress(address _bankAddress) external onlyExecutable {
        require(_bankAddress != address(0), "APM: Address 0 given for Bank!");
        bankAddress = _bankAddress;
    }

    function getReserves(address tokenA, address tokenB) external view returns (uint reserveA, uint reserveB) {
        return (reserveA, reserveB);
    }

    function updateWhenAddLiquidity(
        uint _amountA,
        uint _amountB,
        address _tokenA,
        address _tokenB) external {
        return;
    }

    function swap(uint amount0Out, uint amount1Out,address token0, address token1, address to) external {
        return;
    }

    function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts) {
        return amounts;
    }

    function removeLiquidity(address _to, address tokenAddress, uint amount) external onlyExecutable {
        IERC20(tokenAddress).safeTransfer(_to, amount);
    }
}
