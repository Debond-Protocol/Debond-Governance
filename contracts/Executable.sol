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

import "@debond-protocol/debond-token-contracts/interfaces/IDebondToken.sol";
import "@debond-protocol/debond-token-contracts/interfaces/IDGOV.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IGovStorage.sol";
import "./interfaces/IGovSharedStorage.sol";
import "./interfaces/IExecutable.sol";
import "./interfaces/IUpdatable.sol";

contract Executable is IExecutable, IGovSharedStorage {
    address public govStorageAddress;

    modifier onlyGov {
        require(
            msg.sender == IGovStorage(govStorageAddress).getGovernanceAddress(),
            "Executable: Only Gov"
        );
        _;
    }

    modifier onlyDBITorDGOV(address _tokenAddress) {
        require(
            _tokenAddress == IGovStorage(govStorageAddress).getDGOVAddress() ||
            _tokenAddress == IGovStorage(govStorageAddress).getDBITAddress(),
            "Gov: wrong token address"
        );
        _;
    }

    constructor(address _govStorageAddress) {
        govStorageAddress = _govStorageAddress;
    }

    /**
    * @dev update the benchmark interest rate
    * @param _newBenchmarkInterestRate new benchmark interest rate
    */
    function updateBenchmarkInterestRate(
        uint128 _proposalClass,
        uint256 _newBenchmarkInterestRate
    ) external onlyGov returns(bool) {
        require(_proposalClass < 1, "Executable: invalid class");

        IGovStorage(govStorageAddress).setBenchmarkIR(_newBenchmarkInterestRate);

        IUpdatable(
            IGovStorage(govStorageAddress).getBankAddress()
        ).setBenchmarkIR(_newBenchmarkInterestRate);

        emit benchmarkUpdated(_newBenchmarkInterestRate);

        return true;
    }

    function updateProposalThresholdForProposer(
        uint128 _proposalClass,
        uint256 _newProposalThreshold
    ) external onlyGov returns(bool) {
        require(_proposalClass < 1, "Executable: invalid class");

        IGovStorage(govStorageAddress).setProposalThreshold(_newProposalThreshold);

        return true;
    }

    function createNewBondClass(
        uint128 _proposalClass,
        uint256 _classId,
        string memory _symbol,
        address _tokenAddress,
        InterestRateType _interestRateType,
        uint256 _period
    ) external onlyGov returns(bool) {
        require(_proposalClass <= 1, "Executable: invalid class");

        IUpdatable(
            IGovStorage(govStorageAddress).getBankBondManagerAddress()
        ).createBonClass(
            _classId,
            _symbol,
            _tokenAddress,
            _interestRateType,
            _period
        );

        emit newBondClassCreated(_tokenAddress, _classId, _symbol);

        return true;
    }

    function changeTeamAllocation(
        uint128 _proposalClass,
        address _to,
        uint256 _newDBITPPM,
        uint256 _newDGOVPPM
    ) external onlyGov {
        require(_proposalClass < 1, "Executable: invalid proposal class");
        require(
            IGovStorage(
                govStorageAddress
            ).setTeamAllocation(_to, _newDBITPPM, _newDGOVPPM),
            "Gov: executaion failed"
        );

        emit teamAllocChanged(_to, _newDBITPPM, _newDGOVPPM);
    }

    function changeCommunityFundSize(
        uint128 _proposalClass,
        uint256 _newDBITBudgetPPM,
        uint256 _newDGOVBudgetPPM
    ) external onlyGov {
        require(_proposalClass < 1, "Executable: invalid class");
        require(
            IGovStorage(govStorageAddress).setFundSize(_newDBITBudgetPPM, _newDGOVBudgetPPM)
        );

        emit comunityFundchanged(_newDBITBudgetPPM, _newDGOVBudgetPPM);
    }

    function mintAllocatedToken(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyGov onlyDBITorDGOV(_token) returns(bool) {
        IGovStorage(
            govStorageAddress
        ).setAllocatedToken(_token, _to, _amount);

        return true;
    }

    function migrateToken(
        uint128 _proposalClass,
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) external onlyGov returns(bool) {
        require(_proposalClass <= 2, "Executable: invalid proposal class");

        IUpdatable(_from).migrate(_token, _to, _amount);

        emit tokenMigrated(_token, _from, _to, _amount);

        return true;
    }

    function updateExecutableAddress(
        uint128 _proposalClass,
        address _executableAddress
    ) external onlyGov returns(bool) {
        require(_proposalClass <= 1, "Executable: invalid proposal class");
        IGovStorage(govStorageAddress).updateExecutableAddress(_executableAddress);

        // in Bank
        IUpdatable(
            IGovStorage(govStorageAddress).getBankAddress()
        ).updateExecutable(_executableAddress);
        // in DBIT
        IUpdatable(
            IGovStorage(govStorageAddress).getDBITAddress()
        ).updateExecutable(_executableAddress);
        // in DGOV
        IUpdatable(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).updateExecutable(_executableAddress);
        // in Bank data
        IUpdatable(IGovStorage(
            govStorageAddress).getBankDataAddress()
        ).updateExecutable(_executableAddress);
        // in APM
        IUpdatable(
            IGovStorage(govStorageAddress).getAPMAddress()
        ).updateExecutable(_executableAddress);
        // in Debond Bond
        IUpdatable(
            IGovStorage(govStorageAddress).getERC3475Address()
        ).updateExecutable(_executableAddress);
        // in Exchange storage
        IUpdatable(
            IGovStorage(govStorageAddress).getExchangeStorageAddress()
        ).updateExecutable(_executableAddress);
        // in Exchange
        IUpdatable(
            IGovStorage(govStorageAddress).getExchangeAddress()
        ).updateExecutable(_executableAddress);

        emit exeutableContractUpdated(_executableAddress);

        return true;
    }

    function updateBankAddress(
        uint128 _proposalClass,
        address _bankAddress
    ) external onlyGov returns(bool) {
        require(_proposalClass <= 1, "Executable: invalid proposal class");

        IGovStorage(govStorageAddress).updateBankAddress(_bankAddress);

        // in DBIT
        IUpdatable(
            IGovStorage(govStorageAddress).getDBITAddress()
        ).updateBank(_bankAddress);
        // i DGOV
        IUpdatable(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).updateBank(_bankAddress);
        // in APM
        IUpdatable(
            IGovStorage(govStorageAddress).getAPMAddress()
        ).updateBank(_bankAddress);
        
        // in Debond Bond
        IUpdatable(
            IGovStorage(govStorageAddress).getERC3475Address()
        ).updateBank(_bankAddress);

        // in Bank Data
        IUpdatable(
            IGovStorage(govStorageAddress).getBankDataAddress()
        ).updateBank(_bankAddress);

        // in Bank Bond Manager
        IUpdatable(
            IGovStorage(govStorageAddress).getBankBondManagerAddress()
        ).updateBank(_bankAddress);

        emit bankContractUpdated(_bankAddress);
        
        return true;
    }

    function updateExchangeAddress(
        uint128 _proposalClass,
        address _exchangeAddress
    ) external onlyGov returns(bool) {
        require(_proposalClass <= 1, "Executable: invalid proposal class");

        IGovStorage(govStorageAddress).updateExchangeAddress(_exchangeAddress);

        IUpdatable(
            IGovStorage(govStorageAddress).getExchangeStorageAddress()
        ).updateExchange(_exchangeAddress);

        emit exchangeContractUpdated(_exchangeAddress);

        return true;
    }

    function updateBankBondManagerAddress(
        uint128 _proposalClass,
        address _bankBondManagerAddress
    ) external onlyGov returns(bool) {
        require(_proposalClass <= 1, "Executable: invalid proposal class");

        IGovStorage(
            govStorageAddress
        ).updateBankBondManagerAddress(_bankBondManagerAddress);

        // in Bank
        IUpdatable(
            IGovStorage(govStorageAddress).getBankAddress()
        ).updateBankBondManager(_bankBondManagerAddress);
        // in Debond Bond
        IUpdatable(
            IGovStorage(govStorageAddress).getERC3475Address()
        ).updateBankBondManager(_bankBondManagerAddress);

        emit bondManagerContractUpdated(_bankBondManagerAddress);

        return true;
    }

    function updateOracleAddress(
        uint128 _proposalClass,
        address _oracleAddress
    ) external onlyGov returns(bool) {
        require(_proposalClass <= 1, "Executable: invalid proposal class");

        IGovStorage(govStorageAddress).updateOracleAddress(_oracleAddress);

        // in Bank
        IUpdatable(
            IGovStorage(govStorageAddress).getBankAddress()
        ).updateOracle(_oracleAddress);

        IUpdatable(
            IGovStorage(govStorageAddress).getBankBondManagerAddress()
        ).updateOracle(_oracleAddress);

        emit oracleContractUpdated(_oracleAddress);

        return true;
    }

    function updateAirdropAddress(
        uint128 _proposalClass,
        address _airdropAddress
    ) external onlyGov returns(bool) {
        require(_proposalClass <= 1, "Executable: invalid proposal class");
        IGovStorage(govStorageAddress).updateAirdropAddress(_airdropAddress);

        // in DBIT
        IUpdatable(
            IGovStorage(govStorageAddress).getDBITAddress()
        ).updateAirdrop(_airdropAddress);
        // in DGOV
        IUpdatable(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).updateAirdrop(_airdropAddress);

        emit airdropContractUpdated(_airdropAddress);

        return true;
    }

    function updateGovernanceAddress(
        uint128 _proposalClass,
        address _governanceAddress
    ) external onlyGov returns(bool) {
        require(_proposalClass <= 1, "Executable: invalid proposal class");

        IGovStorage(govStorageAddress).updateGovernanceAddress(_governanceAddress);

        // in Bank
        IUpdatable(
            IGovStorage(govStorageAddress).getBankAddress()
        ).updateGovernance(_governanceAddress);
        // in DBIT
        IUpdatable(
            IGovStorage(govStorageAddress).getDBITAddress()
        ).updateGovernance(_governanceAddress);
        // in DGOV
        IUpdatable(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).updateGovernance(_governanceAddress);
        // in Bank data
        IUpdatable(IGovStorage(
            govStorageAddress).getBankDataAddress()
        ).updateGovernance(_governanceAddress);
        // in APM
        IUpdatable(
            IGovStorage(govStorageAddress).getAPMAddress()
        ).updateGovernance(_governanceAddress);
        // in Debond Bond
        IUpdatable(
            IGovStorage(govStorageAddress).getERC3475Address()
        ).updateGovernance(_governanceAddress);
        // in Exchange storage
        IUpdatable(
            IGovStorage(govStorageAddress).getExchangeStorageAddress()
        ).updateGovernance(_governanceAddress);
        // in Exchange
        IUpdatable(
            IGovStorage(govStorageAddress).getExchangeAddress()
        ).updateGovernance(_governanceAddress);

        emit governanceContractUpdated(_governanceAddress);

        return true;
    }
}