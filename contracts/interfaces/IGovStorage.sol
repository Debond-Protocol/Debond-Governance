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
    function isInitialized() external view returns(bool);
    function getThreshold() external view returns(uint256);
    function getVetoOperator() external view returns(address);
    function getExecutableContract() external view returns(address);
    function getStakingContract() external view returns(address);
    function getProposalLogicContract() external view returns(address);
    function getVoteTokenContract() external view returns(address);
    function getGovSettingContract() external view returns(address);
    function getAirdropContract() external view returns(address);
    function getNumberOfSecondInYear() external pure returns(uint256);

    function getGovernanceAddress() external view returns(address);
    function getExchangeAddress() external view returns(address);
    function getExchangeStorageAddress() external view returns(address);
    function getBankAddress() external view returns(address);
    function getDGOVAddress() external view returns(address);
    function getDBITAddress() external view returns(address);
    function getAPMAddress() external view returns(address);
    function getERC3475Address() external view returns(address);
    function getBankBondManagerAddress() external view returns(address);
    function getBankDataAddress() external view returns(address);
    function getOracleAddress() external view returns(address);
    function getVoteCountingAddress() external view returns(address);
    function getGovernanceOwnableAddress() external view returns(address);
    function getDebondTeamAddress() external view returns(address);
    function getBenchmarkIR() external view returns(uint256);
    function votingInterestRate() external view returns(uint256);
    function stakingInterestRate() external view returns(uint256);
    function getBudget() external view returns(uint256, uint256);
    function getAllocationDistributed() external view returns(uint256, uint256);
    function getTotalAllocationDistributed() external view returns(uint256, uint256);
    function getAllocatedToken(address _account) external view returns(uint256, uint256);
    function getAllocatedTokenMinted(address _account) external view returns(uint256, uint256);
    function getMinimumStakingDuration() external view returns(uint256);

    function updateBankAddress(address _bankAddress) external;
    function updateExchangeAddress(address _exchangeAddress) external;
    function updateBankBondManagerAddress(address _bankBondManagerAddress) external;
    function updateOracleAddress(address _oracleAddress) external;
    function updateAirdropAddress(address _airdropAddress) external;
    function updateGovernanceAddress(address _governanceAddress) external;

    function getProposalStruct(
        uint128 _class,
        uint128 _nonce
    ) external view returns(Proposal memory);

    function getClassQuorum(
        uint128 _class
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
        address,
        uint256,
        bytes memory,
        string memory,
        bytes32
    );

    function getProposalStatus(
        uint128 _class,
        uint128 _nonce
    ) external view returns(ProposalStatus unassigned);

    function getProposalInfoForExecutable(
        uint128 _class,
        uint128 _nonce
    ) external view returns(
        address,
        address,
        uint256,
        bytes memory
    );

    function getProposalProposer(
        uint128 _class,
        uint128 _nonce
    ) external view returns(address);

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

    function dbitDistributedPerDay() external view returns(uint256);

    function setProposal(
        uint128 _class,
        uint128 _nonce,
        uint256 _startTime,
        uint256 _endTime,
        address _proposer,
        ProposalApproval _approvalMode,
        address _targets,
        uint256 _values,
        bytes memory _calldatas,
        string memory _title
    ) external;

    function setProposalDescriptionHash(
        uint128 _class,
        uint128 _nonce,
        bytes32 _descriptionHash
    ) external;

    function setProposalStatus(
        uint128 _class,
        uint128 _nonce,
        ProposalStatus _status
    ) external;

    function getProposalNonce(
        uint128 _class
    ) external view returns(uint128);

    function setProposalNonce(
        uint128 _class,
        uint128 _nonce
    ) external;

    function estimateInterestEarned(
        uint256 _amount,
        uint256 _duration
    ) external view returns(uint256 interest);

    //== FROM EXECUTABLE
    function updateGovernanceContract(
        address _newGovernanceAddress,
        address _executor
    ) external returns(bool);

    function updateExecutableAddress(
        address _executableAddress
    ) external;

    function updateExchangeContract(
        address _newExchangeAddress,
        address _executor
    ) external returns(bool);

    function updateBankContract(
        address _newBankAddress,
        address _executor
    ) external returns(bool);

    function setBenchmarkIR(
        uint256 _newBenchmarkInterestRate
    ) external;

    function setProposalThreshold(
        uint256 _newProposalThreshold
    ) external;

    function setFundSize(
        uint256 _newDBITBudgetPPM,
        uint256 _newDGOVBudgetPPM
    ) external returns(bool);

    function setTeamAllocation(
        address _to,
        uint256 _newDBITPPM,
        uint256 _newDGOVPPM
    ) external returns(bool);

    function setAllocatedToken(
        address _token,
        address _to,
        uint256 _amount
    ) external;

    function claimFundForProposal(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) external returns(bool);

    function checkSupply(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) external view returns(bool);

    function getProposalCallData(
        uint128 _class,
        uint128 _nonce
    ) external view returns(bytes memory);

    function getGovernanceCallData(
        uint128 _class,
        uint128 _nonce,
        address _newGovernanceAddress
    ) external pure returns(bytes memory);

    function decodeGovernanceCallData(
        bytes calldata _data
    ) external pure returns(
        uint128,
        uint128,
        address
    );
}