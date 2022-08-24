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
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IGovStorage.sol";
import "./interfaces/IGovSharedStorage.sol";
import "./interfaces/IExecutable.sol";
import "./interfaces/IUpdatable.sol";

contract Executable is IExecutable, IGovSharedStorage {
    using SafeERC20 for IERC20;
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

    function updateDGOVMaxSupply(
        uint256 _maxSupply
    ) external onlyGov {

        require(
            IDGOV(
                IGovStorage(govStorageAddress).getDGOVAddress()
            ).setMaxSupply(_maxSupply),
            "Gov: Execution failed"
        );

        emit dgovMaxSupplyUpdated(_maxSupply);
    }

    function updateDBITMaxAllocationPercentage(
        uint256 _newPercentage
    ) external onlyGov {

        require(
            IDebondToken(IGovStorage(govStorageAddress).getDBITAddress()).setMaxAllocationPercentage(_newPercentage),
            "Gov: Execution failed"
        );

        emit DbitmaxAllocationSet(_tokenAddress, _newPercentage);
    }

    function updateDGOVMaxAllocationPercentage(
        uint256 _newPercentage
    ) external onlyGov {

        require(
            IDebondToken(IGovStorage(govStorageAddress).getDGOVAddress()).setMaxAllocationPercentage(_newPercentage),
            "Gov: Execution failed"
        );

        emit DgovmaxAllocationSet(_tokenAddress, _newPercentage);
    }

    // TODO name explicitly functions for DBIT and DGOV is better
    function updateDBITMaxAirdropSupply(
        uint256 _newSupply
    ) external onlyGov {
        address _tokenAddress = IGovStorage(govStorageAddress).getDBITAddress();
        require(
            IDebondToken(_tokenAddress).setMaxAirdropSupply(_newSupply),
            "Gov: Execution failed"
        );

        emit maxAirdropSupplyUpdated(_tokenAddress, _newSupply);
    }

    function updateDGOVMaxAirdropSupply(
        uint256 _newSupply
    ) external onlyGov {
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
        uint256 _newBenchmarkInterestRate
    ) external onlyGov returns(bool) {
        IGovStorage(govStorageAddress).setBenchmarkIR(_newBenchmarkInterestRate);

        IUpdatable(
            IGovStorage(govStorageAddress).getBankAddress()
        ).updateBenchmarkIR(_newBenchmarkInterestRate);

        emit benchmarkUpdated(_newBenchmarkInterestRate);

        return true;
    }

    function createNewBondClass(
        uint256 _classId,
        string memory _symbol,
        address _tokenAddress,
        InterestRateType _interestRateType,
        uint256 _period
    ) external onlyGov returns(bool) {

        IUpdatable(
            IGovStorage(govStorageAddress).getBankBondManagerAddress()
        ).createBondClass(
            _classId,
            _symbol,
            _tokenAddress,
            _interestRateType,
            _period
        );

        emit newBondClassCreated(_tokenAddress, _classId, _symbol);

        return true;
    }

    function updataVoteClassInfo(
        uint128 _ProposalClassInfoClass,
        uint256 _timeLock,
        uint256 _minimumApproval,
        uint256 _quorum,
        uint256 _needVeto,
        uint256 _maximumExecutionTime,
        uint256 _minimumExexutionInterval
    ) external onlyGov returns(bool) {
        IGovStorage(govStorageAddress).setProposalClassInfo(_ProposalClassInfoClass, 0, _timeLock);
        IGovStorage(govStorageAddress).setProposalClassInfo(_ProposalClassInfoClass, 1, _minimumApproval);
        IGovStorage(govStorageAddress).setProposalClassInfo(_ProposalClassInfoClass, 2, _quorum);
        IGovStorage(govStorageAddress).setProposalClassInfo(_ProposalClassInfoClass, 3, _needVeto);
        IGovStorage(govStorageAddress).setProposalClassInfo(_ProposalClassInfoClass, 4, _maximumExecutionTime);
        IGovStorage(govStorageAddress).setProposalClassInfo(_ProposalClassInfoClass, 5, _minimumExexutionInterval);

        emit voteClassUpdated(_ProposalClassInfoClass, _quorum);
        return true;
    }

    function changeStampDuty(
        address _to,
        uint256 _newDBITPPM,
        uint256 _newDGOVPPM
    ) external onlyGov {
        require(
            IGovStorage(
                govStorageAddress
            ).setTeamAllocation(_to, _newDBITPPM, _newDGOVPPM),
            "Gov: executaion failed"
        );

        emit teamAllocChanged(_to, _newDBITPPM, _newDGOVPPM);
    }

    function changeCommunityFundSize(
        uint256 _newDBITBudgetPPM,
        uint256 _newDGOVBudgetPPM
    ) external onlyGov {
        require(
            IGovStorage(govStorageAddress).setFundSize(_newDBITBudgetPPM, _newDGOVBudgetPPM)
        );

        emit communityFundChanged(_newDBITBudgetPPM, _newDGOVBudgetPPM);
    }

    function mintDBITAllocatedToken(
        address _to,
        uint256 _amount
    ) external onlyGov returns(bool) {
        address _token = IGovStorage(govStorageAddress).getDBITAddress();
        IGovStorage(
            govStorageAddress
        ).setAllocatedToken(_token, _to, _amount);

        IDebondToken(_token).mintAllocatedSupply(_to, _amount);

        emit allocationTokenMinted(_token, _to, _amount);

        return true;
    }

    function mintDGOVAllocatedToken(
        address _to,
        uint256 _amount
    ) external onlyGov returns(bool) {
        address _token = IGovStorage(govStorageAddress).getDGOVAddress();
        IGovStorage(
            govStorageAddress
        ).setAllocatedToken(_token, _to, _amount);

        IDebondToken(_token).mintAllocatedSupply(_to, _amount);

        emit allocationTokenMinted(_token, _to, _amount);

        return true;
    }

    function migrateToken(
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) external onlyGov returns(bool) {

        IUpdatable(_from).migrate(_token, _to, _amount);

        emit tokenMigrated(_token, _from, _to, _amount);

        return true;
    }

    function updateExecutableAddress(
        address _executableAddress
    ) external onlyGov returns(bool) {
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
        // in Staking contract
        IUpdatable(
            IGovStorage(govStorageAddress).getStakingContract()
        ).updateExecutable(_executableAddress);

        // in Exchange
        IUpdatable(
            IGovStorage(govStorageAddress).getExchangeAddress()
        ).updateExecutable(_executableAddress);

        emit executableContractUpdated(_executableAddress);

        return true;
    }

    function updateBankAddress(
        address _bankAddress
    ) external onlyGov returns(bool) {
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
        address _exchangeAddress
    ) external onlyGov returns(bool) {
        IGovStorage(govStorageAddress).updateExchangeAddress(_exchangeAddress);

        IUpdatable(
            IGovStorage(govStorageAddress).getExchangeStorageAddress()
        ).updateExchange(_exchangeAddress);

        emit exchangeContractUpdated(_exchangeAddress);

        return true;
    }

    function updateBankBondManagerAddress(
        address _bankBondManagerAddress
    ) external onlyGov returns(bool) {
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
        address _oracleAddress
    ) external onlyGov returns(bool) {
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
        address _airdropAddress
    ) external onlyGov returns(bool) {
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
        address _governanceAddress
    ) external onlyGov returns(bool) {
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
        // in Staking contract
        IUpdatable(
            IGovStorage(govStorageAddress).getStakingContract()
        ).updateGovernance(_governanceAddress);

        // in Exchange
        IUpdatable(
            IGovStorage(govStorageAddress).getExchangeAddress()
        ).updateGovernance(_governanceAddress);

        emit governanceContractUpdated(_governanceAddress);

        return true;
    }
}
