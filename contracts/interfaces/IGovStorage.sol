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

interface IGovStorage is IGovSharedStorage {
    function getThreshold() external view returns(uint256);
    function getDebondOperator() external view returns(address);
    function getVetoOperator() external view returns(address);
    function getInterestForStakingDGOV() external view returns(uint256);
    function getExecutableContract() external view returns(address);
    function getStakingContract() external view returns(address);
    function getVoteTokenContract() external view returns(address);
    function getGovSettingContract() external view returns(address);
    function getNumberOfSecondInYear() external pure returns(uint256);

    function getProposalStruct(
        uint128 _class,
        uint128 _nonce
    ) external view returns(Proposal memory);

    function getProposalClassInfo(
        uint128 _class,
        uint256 _index
    ) external view returns(uint256);

    function getProposal(
        uint128 _class,
        uint128 _nonce
    ) external view returns(
        uint256,
        uint256,
        address,
        ProposalStatus,
        ProposalApproval,
        address[] memory,
        uint256[] memory,
        bytes[] memory,
        bytes32
    );

    function getNumberOfVotingDays(
        uint128 _class
    ) external view returns(uint256);

    function getTotalVoteTokenPerDay(
        uint128 _class,
        uint128 _nonce,
        uint256 _votingDay
    ) external view returns(uint256);

    function increaseTotalVoteTokenPerDay(
        uint128 _class,
        uint128 _nonce,
        uint256 _votingDay,
        uint256 _amountVoteTokens
    ) external;

    function getNumberOfDBITDistributedPerDay(
        uint128 _class
    ) external view returns(uint256);

    function setThreshold(uint256 _newProposalThreshold) external;
    function setProposal(
        uint128 _class,
        uint128 _nonce,
        uint256 _startTime,
        uint256 _endTime,
        address _proposer,
        ProposalApproval _approvalMode,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    ) external;

    function setProposalStatus(
        uint128 _class,
        uint128 _nonce,
        ProposalStatus _status
    ) external;

    function setProposalClassInfo(
        uint128 _class,
        uint256 _index,
        uint256 _value
    ) external;

    function getProposalNonce(
        uint128 _class
    ) external view returns(uint128);

    function setProposalNonce(
        uint128 _class,
        uint128 _nonce
    ) external;

    //== FROM EXECUTABLE
    function updateGovernanceContract(
        address _newGovernanceAddress,
        address _executor
    ) external returns(bool);

    function updateExchangeContract(
        address _newExchangeAddress,
        address _executor
    ) external returns(bool);

    function updateBankContract(
        address _newBankAddress,
        address _executor
    ) external returns(bool);

    function updateBenchmarkInterestRate(
        uint256 _newBenchmarkInterestRate,
        address _executor
    ) external returns(bool);

    function changeCommunityFundSize(
        uint256 _newDBITBudgetPPM,
        uint256 _newDGOVBudgetPPM,
        address _executor
    ) external returns(bool);

    function changeTeamAllocation(
        address _to,
        uint256 _newDBITPPM,
        uint256 _newDGOVPPM,
        address _executor
    ) external returns(bool);

    function mintAllocatedToken(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV,
        address _executor
    ) external returns(bool);

    function claimFundForProposal(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) external returns(bool);

    function getGovernanceAddress() external view returns(address);
    function getExchangeAddress() external view returns(address);
    function getBankAddress() external view returns(address);
    function getDGOVAddress() external view returns(address);
    function getDBITAddress() external view returns(address);
    function getVoteCountingAddress() external view returns(address);
    function getDebondTeamAddress() external view returns(address);
    function getBenchmarkInterestRate() external view returns(uint256);
    function getBudget() external view returns(uint256, uint256);
    function getAllocationDistributed() external view returns(uint256, uint256);
    function getTotalAllocationDistributed() external view returns(uint256, uint256);
    function getAllocatedToken(address _account) external view returns(uint256, uint256);
    function getAllocatedTokenMinted(address _account) external view returns(uint256, uint256);
}