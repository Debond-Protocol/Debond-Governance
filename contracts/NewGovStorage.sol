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

import "./interfaces/INewGovernance.sol";

abstract contract NewGovStorage is INewGovernance {
    address public debondOperator;
    address public governance;
    address public bankContract;
    address public dgovContract;
    address public dbitContract;
    address public stakingContract;
    address public voteTokenContract;
    address public govSettingsContract;

    uint256 internal benchmarkInterestRate;
    uint256 public interestRateForStakingDGOV;
    uint256 internal _proposalThreshold;
    uint256 constant public NUMBER_OF_SECONDS_IN_DAY = 31536000;

    mapping(uint128 => mapping(uint128 => Proposal)) proposal;

    modifier onlyDebondOperator {
        require(msg.sender == debondOperator, "Gov: Need rights");
        _;
    }
}