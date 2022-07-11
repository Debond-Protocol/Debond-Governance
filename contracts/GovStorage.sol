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

import "./interfaces/IGovernance.sol";

abstract contract GovStorage is IGovernance {
    struct AllocatedToken {
        uint256 allocatedDBITMinted;
        uint256 allocatedDGOVMinted;
        uint256 dbitAllocationPPM;
        uint256 dgovAllocationPPM;
    }

    bool public initialized;

    address public debondOperator;
    address public debondTeam;
    address public governance;
    address public exchangeContract;
    address public bankContract;
    address public dgovContract;
    address public dbitContract;
    address public stakingContract;
    address public voteTokenContract;
    address public govSettingsContract;

    address public vetoOperator;

    uint256 public dbitBudgetPPM;
    uint256 public dgovBudgetPPM;
    uint256 public dbitAllocationDistibutedPPM;
    uint256 public dgovAllocationDistibutedPPM;
    uint256 public dbitTotalAllocationDistributed;
    uint256 public dgovTotalAllocationDistributed;

    uint256 internal benchmarkInterestRate;
    uint256 public interestRateForStakingDGOV;
    uint256 internal _proposalThreshold;
    uint256 constant public NUMBER_OF_SECONDS_IN_DAY = 31536000;

    mapping(uint128 => mapping(uint128 => Proposal)) proposal;
    mapping(address => AllocatedToken) allocatedToken;

    modifier onlyDebondOperator {
        require(msg.sender == debondOperator, "Gov: Need rights");
        _;
    }
}