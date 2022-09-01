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

import "./IGovSharedStorage.sol";

interface IExecutable {
    //Update benchmark intrest rate
    function updateBenchmarkInterestRate(
        uint128 _proposalClass,
        uint256 _newBenchmarkInterestRate
    ) external returns(bool);

    function updateProposalThresholdForProposer(
        uint128 _proposalClass,
        uint256 _newProposalThreshold
    ) external returns(bool);

    function createNewBondClass(
        uint128 _proposalClass,
        uint256 _classId,
        string memory _symbol,
        address _tokenAddress,
        IGovSharedStorage.InterestRateType _interestRateType,
        uint256 _period
    ) external returns(bool);

    function migrateToken(
        uint128 _proposalClass,
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) external returns(bool);

    function mintAllocatedToken(
        address _token,
        address _to,
        uint256 _amount
    ) external returns(bool);

    function changeTeamAllocation(
        uint128 _proposalClass,
        address _to,
        uint256 _newDBITPPM,
        uint256 _newDGOVPPM
    ) external;

    function changeCommunityFundSize(
        uint128 _proposalClass,
        uint256 _newDBITBudgetPPM,
        uint256 _newDGOVBudgetPPM
    ) external;

    function updateExecutableAddress(
        uint128 _proposalClass,
        address _executableAddress
    ) external returns(bool);

    function updateBankAddress(
        uint128 _proposalClass,
        address _bankAddress
    ) external returns(bool);

    function updateExchangeAddress(
        uint128 _proposalClass,
        address _exchangeAddress
    ) external returns(bool);

    function updateBankBondManagerAddress(
        uint128 _proposalClass,
        address _bankBondManagerAddress
    ) external returns(bool);

    function updateOracleAddress(
        uint128 _proposalClass,
        address _oracleAddress
    ) external returns(bool);

    function updateAirdropAddress(
        uint128 _proposalClass,
        address _airdropAddress
    ) external returns(bool);

    function updateGovernanceAddress(
        uint128 _proposalClass,
        address _governanceAddress
    ) external returns(bool);
}