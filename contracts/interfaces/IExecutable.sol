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
        uint256 _newBenchmarkInterestRate
    ) external returns(bool);

    function createNewBondClass(
        uint256 _classId,
        string memory _symbol,
        address _tokenAddress,
        IGovSharedStorage.InterestRateType _interestRateType,
        uint256 _period
    ) external returns(bool);

    function updateVoteClassInfo(
        uint128 _ProposalClassInfoClass,
        uint256 _timeLock,
        uint256 _minimumApproval,
        uint256 _quorum,
        uint256 _needVeto,
        uint256 _maximumExecutionTime,
        uint256 _minimumExexutionInterval
    ) external returns(bool);

    function migrateToken(
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) external returns(bool);

    function changeCommunityFundSize(
        uint256 _newDBITBudgetPPM,
        uint256 _newDGOVBudgetPPM
    ) external;

    function updateExecutableAddress(
        address _executableAddress
    ) external returns(bool);

    function updateBankAddress(
        address _bankAddress
    ) external returns(bool);

    function updateExchangeAddress(
        address _exchangeAddress
    ) external returns(bool);

    function updateBankBondManagerAddress(
        address _bankBondManagerAddress
    ) external returns(bool);

    function updateOracleAddress(
        address _oracleAddress
    ) external returns(bool);

    function updateAirdropAddress(
        address _airdropAddress
    ) external returns(bool);

    function updateGovernanceAddress(
        address _governanceAddress
    ) external returns(bool);
}
