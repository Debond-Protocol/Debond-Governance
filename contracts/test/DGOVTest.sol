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

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../utils/ExecutableOwnable.sol";


contract DGOVTest is ERC20, ExecutableOwnable {

    address bankAddress;
    mapping(address => uint256) allocatedBalance;
    uint maxSupply = 1000000 ether;
    uint256 maxAllocationPercentage;


    constructor(
        address _executableAddress
    ) ERC20("DGOV", "DGOV") ExecutableOwnable(_executableAddress) {}

    function updateBankAddress(address _bankAddress) external onlyExecutable {
        bankAddress = _bankAddress;
    }

    function mintAllocatedSupply(address _to, uint256 _amount) external {
        _mint(_to, _amount);
        allocatedBalance[_to] += _amount;
    }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }

    function getAllocatedBalance(address _account) external view returns(uint256) {
        return allocatedBalance[_account];
    }

    function getTotalCollateralisedSupply() external view returns(uint256) {
        return totalSupply();
    }

    function setMaxSupply(uint256 max_supply) external returns (bool) {
        maxSupply = max_supply;
        return true;
    }

    function getMaxSupply() external view returns(uint256) {
        return maxSupply;
    }

    function setMaxAllocationPercentage(uint256 newPercentage) external returns (bool) {
        maxAllocationPercentage = newPercentage;
        return true;
    }

    function getMaxAllocatedPercentage() external view returns(uint256) {
        return maxAllocationPercentage;
    }


}
