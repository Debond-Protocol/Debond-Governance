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
import "@debond-protocol/debond-apm-contracts/interfaces/IAPM.sol";
import "@debond-protocol/debond-erc3475-contracts/interfaces/IDebondBond.sol";
import "@debond-protocol/debond-bank-contracts/interfaces/IBankBondManager.sol";
import "@debond-protocol/debond-bank-contracts/interfaces/Types.sol";
import "@debond-protocol/debond-bank-contracts/interfaces/IBank.sol";
import "@debond-protocol/debond-bank-contracts/interfaces/IBankStorage.sol";
import "@debond-protocol/debond-exchange-contracts/interfaces/IExchangeStorage.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IGovStorage.sol";
import "./interfaces/IGovSharedStorage.sol";
import "./interfaces/IExecutableUpdatable.sol";
import "./interfaces/IMigrate.sol";

contract Executable is IGovSharedStorage {
    using SafeERC20 for IERC20;
    address public govStorageAddress;

    modifier onlyGov {
        require(
            msg.sender == IGovStorage(govStorageAddress).getGovernanceAddress(),
            "Executable: Only Gov"
        );
        _;
    }

    constructor(address _govStorageAddress) {
        govStorageAddress = _govStorageAddress;
    }

    function updateDGOVMaxSupply(
        uint128 _proposalClass,
        uint256 _maxSupply
    ) external onlyGov {

        require(_proposalClass < 1, "Executable: invalid class");

        require(
            IDGOV(
                IGovStorage(govStorageAddress).getDGOVAddress()
            ).setMaxSupply(_maxSupply),
            "Gov: Execution failed"
        );

        emit dgovMaxSupplyUpdated(_maxSupply);
    }

    function setMaxAllocationPercentage(
        uint128 _proposalClass,
        uint256 _newPercentage,
        address _token
    ) external onlyGov {

        require(_proposalClass < 1, "Executable: invalid class");

        require(
            IDebondToken(_token).setMaxAllocationPercentage(_newPercentage),
            "Gov: Execution failed"
        );

        emit maxAllocationSet(_token, _newPercentage);
    }

    function updateDGOVMaxAirdropSupply(
        uint128 _proposalClass,
        uint256 _newSupply
    ) external onlyGov {
        require(_proposalClass < 1, "Executable: invalid class");
        address _tokenAddress = IGovStorage(govStorageAddress).getDGOVAddress();
        require(
            IDebondToken(_tokenAddress).setMaxAirdropSupply(_newSupply),
            "Gov: Execution failed"
        );

        emit maxAirdropSupplyUpdated(_tokenAddress, _newSupply);
    }

    /**
    * @dev update the benchmark interest rate
    * @param _newBenchmarkInterestRate new benchmark interest rate
    */
    function updateBenchmarkInterestRate(
        uint128 _proposalClass,
        uint256 _newBenchmarkInterestRate
    ) external onlyGov returns (bool) {
        require(_proposalClass < 1, "Executable: invalid class");

        IGovStorage(govStorageAddress).setBenchmarkIR(_newBenchmarkInterestRate);

        IBankStorage(
            IGovStorage(govStorageAddress).getBankDataAddress()
        ).updateBenchmarkInterest(_newBenchmarkInterestRate);

        emit benchmarkUpdated(_newBenchmarkInterestRate);

        return true;
    }

    function updateProposalThreshold(
        uint128 _proposalClass,
        uint256 _newProposalThreshold
    ) external onlyGov returns (bool) {
        require(_proposalClass < 1, "Executable: invalid class");

        IGovStorage(govStorageAddress).setProposalThreshold(_newProposalThreshold);

        return true;
    }

    function createNewBondClass(
        uint128 _proposalClass,
        uint256 _classId,
        string memory _symbol,
        address _tokenAddress,
        Types.InterestRateType _interestRateType,
        uint256 _period
    ) external onlyGov returns (bool) {
        require(_proposalClass <= 1, "Executable: invalid class");

        IBankBondManager(
            IGovStorage(govStorageAddress).getBankBondManagerAddress()
        ).createClass(
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
        require(_proposalClass <= 1, "Executable: invalid proposal class");
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
        require(_proposalClass <= 1, "Executable: invalid class");
        require(
            IGovStorage(govStorageAddress).setFundSize(_newDBITBudgetPPM, _newDGOVBudgetPPM)
        );

        emit communityFundChanged(_newDBITBudgetPPM, _newDGOVBudgetPPM);
    }

    function migrateToken(
        uint128 _proposalClass,
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) external onlyGov returns (bool) {
        require(_proposalClass <= 1, "Executable: invalid proposal class");

        IMigrate(_from).migrate(_token, _to, _amount);

        emit tokenMigrated(_token, _from, _to, _amount);

        return true;
    }

    function updateExecutableAddress(
        uint128 _proposalClass,
        address _executableAddress
    ) external onlyGov returns (bool) {
        require(_proposalClass <= 1, "Executable: invalid proposal class");
        IGovStorage(govStorageAddress).updateExecutableAddress(_executableAddress);

        // in Bank
        IExecutableUpdatable(
            IGovStorage(govStorageAddress).getBankAddress()
        ).updateExecutableAddress(_executableAddress);
        // in Bank data
        IExecutableUpdatable(IGovStorage(
            govStorageAddress).getBankDataAddress()
        ).updateExecutableAddress(_executableAddress);
        // in Bank data
        IExecutableUpdatable(IGovStorage(
            govStorageAddress).getBankBondManagerAddress()
        ).updateExecutableAddress(_executableAddress);
        // in DBIT
        IExecutableUpdatable(
            IGovStorage(govStorageAddress).getDBITAddress()
        ).updateExecutableAddress(_executableAddress);
        // in DGOV
        IExecutableUpdatable(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).updateExecutableAddress(_executableAddress);
        // in APM
        IExecutableUpdatable(
            IGovStorage(govStorageAddress).getAPMAddress()
        ).updateExecutableAddress(_executableAddress);
        // in Debond Bond
        IExecutableUpdatable(
            IGovStorage(govStorageAddress).getERC3475Address()
        ).updateExecutableAddress(_executableAddress);
        // in Exchange
        IExecutableUpdatable(
            IGovStorage(govStorageAddress).getExchangeAddress()
        ).updateExecutableAddress(_executableAddress);
        // in Staking contract
        IExecutableUpdatable(
            IGovStorage(govStorageAddress).getStakingContract()
        ).updateExecutableAddress(_executableAddress);

        emit executableContractUpdated(_executableAddress);

        return true;
    }

    function updateBankAddress(
        uint128 _proposalClass,
        address _bankAddress
    ) external onlyGov returns (bool) {
        require(_proposalClass <= 1, "Executable: invalid proposal class");

        IGovStorage(govStorageAddress).updateBankAddress(_bankAddress);

        // in DBIT
        IDebondToken(
            IGovStorage(govStorageAddress).getDBITAddress()
        ).updateBankAddress(_bankAddress);
        // in DGOV
        IDebondToken(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).updateBankAddress(_bankAddress);
        // in APM
        IAPM(
            IGovStorage(govStorageAddress).getAPMAddress()
        ).updateBankAddress(_bankAddress);

        // in Debond Bond
        IDebondBond(
            IGovStorage(govStorageAddress).getERC3475Address()
        ).updateRedeemableAddress(_bankAddress);

        // in Bank Data
        IBankStorage(
            IGovStorage(govStorageAddress).getBankDataAddress()
        ).updateBankAddress(_bankAddress);

        // in Bank Bond Manager
        IBankBondManager(
            IGovStorage(govStorageAddress).getBankBondManagerAddress()
        ).updateBankAddress(_bankAddress);

        emit bankContractUpdated(_bankAddress);

        return true;
    }

    function updateExchangeAddress(
        uint128 _proposalClass,
        address _exchangeAddress
    ) external onlyGov returns (bool) {
        require(_proposalClass <= 1, "Executable: invalid proposal class");

        IGovStorage(govStorageAddress).updateExchangeAddress(_exchangeAddress);

        IExchangeStorage(
            IGovStorage(govStorageAddress).getExchangeStorageAddress()
        ).setExchangeAddress(_exchangeAddress);

        emit exchangeContractUpdated(_exchangeAddress);

        return true;
    }

    function updateBankBondManagerAddress(
        uint128 _proposalClass,
        address _bankBondManagerAddress
    ) external onlyGov returns (bool) {
        require(_proposalClass <= 1, "Executable: invalid proposal class");

        IGovStorage(
            govStorageAddress
        ).updateBankBondManagerAddress(_bankBondManagerAddress);

        // in Bank
        IBank(
            IGovStorage(govStorageAddress).getBankAddress()
        ).updateBondManagerAddress(_bankBondManagerAddress);
        // in Debond Bond
        IDebondBond(
            IGovStorage(govStorageAddress).getERC3475Address()
        ).updateBondManagerAddress(_bankBondManagerAddress);

        emit bondManagerContractUpdated(_bankBondManagerAddress);

        return true;
    }

    function updateOracleAddress(
        uint128 _proposalClass,
        address _oracleAddress
    ) external onlyGov returns (bool) {
        require(_proposalClass <= 1, "Executable: invalid proposal class");

        // in Bank
        IBank(
            IGovStorage(govStorageAddress).getBankAddress()
        ).updateOracleAddress(_oracleAddress);

        IBankBondManager(
            IGovStorage(govStorageAddress).getBankBondManagerAddress()
        ).updateOracleAddress(_oracleAddress);

        emit oracleContractUpdated(_oracleAddress);

        return true;
    }

    function mintAllocatedToken(
        uint128 _proposalClass,
        address _token,
        address _to,
        uint256 _amount
    ) external onlyGov returns (bool) {
        require(_proposalClass <= 1, "Executable: invalid proposal class");

        IGovStorage(
            govStorageAddress
        ).setAllocatedToken(_token, _to, _amount);

        IDebondToken(_token).mintAllocatedSupply(_to, _amount);


        return true;
    }
}
