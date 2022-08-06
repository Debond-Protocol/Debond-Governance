pragma solidity ^0.8.0;

// SPDX-License-Identifier: apache 2.0
/*
    Copyright 2020 Sigmoid Foundation <info@SGM.finance>
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

import "../interfaces/IGovSettings.sol";
import "../interfaces/IGovStorage.sol";

contract GovSettings is IGovSettings {
    mapping(uint128 => uint256) private _votingPeriod;

    address govStorageAddress;

    event votingDelaySet(uint256 oldDelay, uint256 newDelay);
    event votingPeriodSet(uint256 oldPeriod, uint256 newPeriod);

    event periodSet(uint128 _class, uint256 _period);

    modifier onlyDebondExecutor {
        require(
            msg.sender == IGovStorage(govStorageAddress).getDebondTeamAddress() ||
            msg.sender == IGovStorage(govStorageAddress).getVetoOperator(),
            "Gov: can't execute this task"
        );
        _;
    }

    constructor(
        address _govStorageAddress
    ) {
        govStorageAddress = _govStorageAddress;

        _votingPeriod[0] = 17;
        _votingPeriod[1] = 17;
        _votingPeriod[2] = 17;
    }

    //===
    function getVotingPeriod(uint128 _class) public view returns(uint256) {
        return _votingPeriod[_class];
    }

    function setVotingPeriod(uint128 _class, uint256 _period) public onlyDebondExecutor {
        _setPeriod(_class, _period);
        emit periodSet(_class, _period);
    }

    function _setPeriod(uint128 _class, uint256 _period) private {
        emit periodSet(_class, _period);
        _votingPeriod[_class] = _period;
    }
}