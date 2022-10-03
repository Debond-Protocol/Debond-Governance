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

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IGovStorage.sol";
import "../interfaces/IGovSharedStorage.sol";
import "../interfaces/IMigrate.sol";

contract GovernanceMigrator is IMigrate {
    using SafeERC20 for IERC20;
    uint8 private _lock;
    address public govStorage;

    modifier onlyExecutable {
        require(
            msg.sender == IGovStorage(govStorage).getExecutableContract(),
            "GovernanceMigrator: Only Exec"
        );
        _;
    }

    function setGovStorageAddress(address _govStorageAddress) public {
        require(_lock == 0, "GovernanceMigrator: goStorage address already set");
        govStorage = _govStorageAddress;
        _lock == 1;
    }

    function migrate(
        address _token,
        address _to,
        uint256 _amount
    ) external virtual onlyExecutable {
        IERC20(_token).safeTransfer(_to, _amount);
    }
}
