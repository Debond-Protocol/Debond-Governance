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
    uint256 private _votingDelay;
    uint256 private _votingPeriod;
    address govStorageAddress;

    event votingDelaySet(uint256 oldDelay, uint256 newDelay);
    event votingPeriodSet(uint256 oldPeriod, uint256 newPeriod);

    modifier onlyDebondExecutor {
        require(
            msg.sender == IGovStorage(govStorageAddress).getDebondTeamAddress() ||
            msg.sender == IGovStorage(govStorageAddress).getDebondOperator(),
            "Gov: can't execute this task"
        );
        _;
    }

    constructor(
        uint256 _initialVotingDelay,
        uint256 _initialVotingPeriod,
        address _govStorageAddress
    ) {
        _votingDelay = _initialVotingDelay;
        _votingPeriod = _initialVotingPeriod;
        govStorageAddress = _govStorageAddress;
    }

    function votingDelay() public view override returns(uint256) {
        return _votingDelay;
    }

    function votingPeriod() public view override returns(uint256) {
        return _votingPeriod;
    }

    function setVotingDelay(uint256 _newDelay) public onlyDebondExecutor override {
        _setVotingDelay(_newDelay);
    }

    function setVotingPeriod(uint256 _newPeriod) public onlyDebondExecutor override {
        _setVotingPeriod(_newPeriod);
    }



    function _setVotingDelay(uint256 _newDelay) internal {
        emit votingDelaySet(_votingDelay, _newDelay);
        _votingDelay = _newDelay;
    }

    function _setVotingPeriod(uint256 _newPeriod) internal {
        emit votingPeriodSet(_votingPeriod, _newPeriod);
        _votingPeriod = _newPeriod;
    }
}