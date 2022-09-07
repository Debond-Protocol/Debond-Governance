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

import "@debond-protocol/debond-token-contracts/interfaces/IDGOV.sol";
import "@debond-protocol/debond-token-contracts/interfaces/IDebondToken.sol";
import "@debond-protocol/debond-exchange-contracts/interfaces/IExchangeStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IGovStorage.sol";
import "./interfaces/IProposalLogic.sol";

contract GovStorage is IGovStorage {
    struct AllocatedToken {
        uint256 allocatedDBITMinted;
        uint256 allocatedDGOVMinted;
        uint256 dbitAllocationPPM;
        uint256 dgovAllocationPPM;
    }

    struct ProposalNonce {
        uint128 nonce;
    }

    mapping(uint128 => uint256) numberOfVotingDays;

    bool public initialized;

    address public debondTeam;
    address public governance;
    address public exchangeContract;
    address public exchangeStorageContract;
    address public erc3475Contract;
    address public bankContract;
    address public bankDataContract;
    address public dgovContract;
    address public dbitContract;
    address public apmContract;
    address public bankBondManagerContract;
    address public stakingContract;
    address public voteTokenContract;
    address public proposalLogicContract;
    address public executable;
    address public airdropContract;
    address public governanceOwnableContract;
    address public oracleContract;
    address public governanceMigrator;
    address public interestRatesContract;

    address public vetoOperator;

    uint256 public dbitBudgetPPM;
    uint256 public dgovBudgetPPM;
    uint256 public dbitAllocationDistibutedPPM;
    uint256 public dgovAllocationDistibutedPPM;
    uint256 public dbitTotalAllocationDistributed;
    uint256 public dgovTotalAllocationDistributed;

    uint256 public benchmarkInterestRate;
    uint256 private _proposalThreshold;
    uint256 public minimumStakingDuration;
    uint256 constant private NUMBER_OF_SECONDS_IN_YEAR = 31536000;

    mapping(uint128 => mapping(uint128 => Proposal)) proposal;
    mapping(uint128 =>  uint256) private _proposalQuorum;
    mapping(address => AllocatedToken) allocatedToken;

    uint256 _lockGroup1;
    uint256 _lockGroup2;

    // links proposal class to proposal nonce
    mapping(uint128 => uint128) public proposalNonce;
    // total vote tokens collected per day for a given proposal
    // key1: proposal class, key2: proposal nonce, key3: voting day (1, 2, 3, etc.)
    mapping(uint128 => mapping(uint128 => mapping(uint256 => uint256))) public totalVoteTokenPerDay;

    Proposal[] proposals;

    modifier onlyVetoOperator {
        require(msg.sender == vetoOperator, "Gov: Need rights");
        _;
    }

    modifier onlyGov {
        require(
            msg.sender == getGovernanceAddress(),
            "Gov: Only Gouvernance"
        );
        _;
    }

    modifier onlyExec {
        require(
            msg.sender == getExecutableContract(),
            "GovStorage: Only Exec"
        );
        _;
    }

    modifier onlyProposalLogic {
        require(
            msg.sender == getProposalLogicContract()
        );
        _;
    }

    modifier onlyDBITorDGOV(address _tokenAddress) {
        require(
            _tokenAddress == dbitContract ||
            _tokenAddress == dgovContract,
            "Gov: wrong token address"
        );
        _;
    }

    constructor(
        address _debondTeam,
        address _vetoOperator
    ) {
        _proposalThreshold = 10 ether;

        debondTeam = _debondTeam;
        vetoOperator = _vetoOperator;

        // in percent
        benchmarkInterestRate = 5 * 10**16;

        dbitBudgetPPM = 1e5 * 1 ether;
        dgovBudgetPPM = 1e5 * 1 ether;

        allocatedToken[debondTeam].dbitAllocationPPM = 4e4 * 1 ether;
        allocatedToken[debondTeam].dgovAllocationPPM = 8e4 * 1 ether;

        _proposalQuorum[0] = 70;
        _proposalQuorum[1] = 60;
        _proposalQuorum[2] = 50;

        // voting rewards by class
        numberOfVotingDays[0] = 1;
        numberOfVotingDays[1] = 1;
        numberOfVotingDays[2] = 1;
        minimumStakingDuration = 10;
    }

    function setUpGoup1(
        address _governance,
        address _dgovContract,
        address _dbitContract,
        address _apmContract,
        address _bankBondManagerContract,
        address _oracleContract,
        address _stakingContract,
        address _interestRatesContract,
        address _voteContract
    ) external onlyVetoOperator {
        require(_lockGroup1 == 0, "GovStorage: Group1 already set");

        governance = _governance;
        dgovContract = _dgovContract;
        dbitContract = _dbitContract;
        apmContract = _apmContract;
        bankBondManagerContract = _bankBondManagerContract;
        oracleContract = _oracleContract;
        stakingContract = _stakingContract;
        voteTokenContract = _voteContract;
        interestRatesContract = _interestRatesContract;

        _lockGroup1 == 1;
    }

    function setUpGoup2(
        address _proposalLogicContract,
        address _executable,
        address _bankContract,
        address _bankDataContract,
        address _erc3475Contract,
        address _exchangeContract,
        address _exchangeStorageContract,
        address _airdropContract,
        address _governanceOwnableContract
    ) external onlyVetoOperator {
        require(_lockGroup2 == 0, "GovStorage: Group2 already set");

        proposalLogicContract = _proposalLogicContract;
        executable = _executable;
        bankContract = _bankContract;
        bankDataContract = _bankDataContract;
        erc3475Contract = _erc3475Contract;
        exchangeContract = _exchangeContract;
        exchangeStorageContract = _exchangeStorageContract;
        airdropContract = _airdropContract;
        governanceOwnableContract = _governanceOwnableContract;

        _lockGroup2 == 1;
    }

    function isInitialized() public view returns(bool) {
        return initialized;
    }

    function initializeDebond() public onlyVetoOperator returns(bool) {
        require(initialized == false, "Gov: Debond alraedy initialized");
        require(dbitContract != address(0), "GovStorage: check DBIT address");
        require(dgovContract != address(0), "GovStorage: check DGOV address");
        require(bankContract != address(0), "GovStorage: check Bank address");
        require(exchangeContract != address(0), "GovStorage: check Exchange address");
        require(airdropContract != address(0), "GovStorage: check Airdrop address");
        require(exchangeStorageContract != address(0), "GovStorage: check exchange storage address");

        IDebondToken(
            dbitContract
        ).setExchangeAddress(exchangeContract);

        IDebondToken(
            dbitContract
        ).setAirdropAddress(airdropContract);

        IDebondToken(
            dbitContract
        ).setAirdropAddress(bankContract);

        IDebondToken(
            dgovContract
        ).setExchangeAddress(exchangeContract);

        IDebondToken(
            dgovContract
        ).setAirdropAddress(airdropContract);

        IDebondToken(
            dgovContract
        ).setAirdropAddress(bankContract);

        IExchangeStorage(
            exchangeStorageContract
        ).setExchangeAddress(exchangeContract);
        
        initialized = true;
        return true;
    }

    function getProposalThreshold() public view returns(uint256) {
        return _proposalThreshold;
    }

    function getMinimumStakingDuration() public view returns(uint256) {
        return minimumStakingDuration;
    }

    function getVetoOperator() public view returns(address) {
        return vetoOperator;
    }

    function getExecutableContract() public view returns(address) {
        return executable;
    }

    function getStakingContract() public view returns(address) {
        return stakingContract;
    }

    function getInterestRatesContract() public view returns(address) {
        return interestRatesContract;
    }

    function getVoteTokenContract() public view returns(address) {
        return voteTokenContract;
    }

    function getProposalLogicContract() public view returns(address) {
        return proposalLogicContract;
    }

    function getAirdropContract() public view returns(address) {
        return airdropContract;
    }

    function getGovernanceAddress() public view returns(address) {
        return governance;
    }

    function getExchangeAddress() public view returns(address) {
        return exchangeContract;
    }

    function getExchangeStorageAddress() public view returns(address) {
        return exchangeStorageContract;
    }

    function getBankAddress() public view returns(address) {
        return bankContract;
    }

    function getDGOVAddress() public view returns(address) {
        return dgovContract;
    }

    function getDBITAddress() public view returns(address) {
        return dbitContract;
    }

    function getAPMAddress() public view returns(address) {
        return apmContract;
    }

    function getERC3475Address() public view returns(address) {
        return erc3475Contract;
    }

    function getBankBondManagerAddress() public view returns(address) {
        return bankBondManagerContract;
    }

    function getBankDataAddress() public view returns(address) {
        return bankDataContract;
    }

    function getOracleAddress() public view returns(address) {
        return oracleContract;
    }

    function getGovernanceOwnableAddress() public view returns(address) {
        return governanceOwnableContract;
    }

    function getDebondTeamAddress() public view returns(address) {
        return debondTeam;
    }

    function getNumberOfSecondInYear() public pure returns(uint256) {
        return NUMBER_OF_SECONDS_IN_YEAR;
    }

    function getBenchmarkIR() public view returns(uint256) {
        return benchmarkInterestRate;
    }

    function _getDGOVBalanceOfStakingContract() internal view returns(uint256) {
        return IERC20(dgovContract).balanceOf(stakingContract);
    }

    function getBudget() public view returns(uint256, uint256) {
        return (dbitBudgetPPM, dgovBudgetPPM);
    }

    function getAllocationDistributed() public view returns(uint256, uint256) {
        return (dbitAllocationDistibutedPPM, dgovAllocationDistibutedPPM);
    }

    function getTotalAllocationDistributed() public view returns(uint256, uint256) {
        return (dbitTotalAllocationDistributed, dgovTotalAllocationDistributed);
    }

    function getAllocatedToken(address _account) public view returns(uint256, uint256) {
        return (
            allocatedToken[_account].dbitAllocationPPM,
            allocatedToken[_account].dgovAllocationPPM
        );
    }

    function getAllocatedTokenMinted(address _account) public view returns(uint256, uint256) {
        return (
            allocatedToken[_account].allocatedDBITMinted,
            allocatedToken[_account].allocatedDGOVMinted
        );
    }

    function getProposalStruct(
        uint128 _class,
        uint128 _nonce
    ) public view returns(Proposal memory) {
        return proposal[_class][_nonce];
    }

    /**
    * @dev return proposal proposer
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function getProposalProposer(
        uint128 _class,
        uint128 _nonce
    ) external view returns(address) {
        return proposal[_class][_nonce].proposer;
    }

    function getClassQuorum(uint128 _class) public view returns(uint256) {
        return _proposalQuorum[_class];
    }

    /**
    * @dev return the proposal status
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function getProposalStatus(
        uint128 _class,
        uint128 _nonce
    ) public view returns(ProposalStatus unassigned) {
        Proposal memory _proposal = getProposalStruct(_class, _nonce);
        
        if (_proposal.status == ProposalStatus.Canceled) {
            return ProposalStatus.Canceled;
        }

        if (_proposal.status == ProposalStatus.Executed) {
            return ProposalStatus.Executed;
        }

        if (block.timestamp <= _proposal.endTime) {
            return ProposalStatus.Active;
        }

        if(!IProposalLogic(proposalLogicContract).voteSucceeded(_class, _nonce)) {
            return ProposalStatus.Defeated;
        } else {
            if(!IProposalLogic(proposalLogicContract).quorumReached(_class, _nonce)) {
                return ProposalStatus.Defeated;
            } else {
                if(IProposalLogic(proposalLogicContract).vetoed(_class, _nonce)) {
                    return ProposalStatus.Defeated;
                } else {
                    return ProposalStatus.Succeeded;
                }
            }
        }
    }

    function getNumberOfVotingDays(
        uint128 _class
    ) public view returns(uint256) {
        return numberOfVotingDays[_class];
    }

    function getTotalVoteTokenPerDay(
        uint128 _class,
        uint128 _nonce,
        uint256 _votingDay
    ) public view returns(uint256 total) {
        for (uint256 i = 1; i <= _votingDay; i++) {
            total += totalVoteTokenPerDay[_class][_nonce][i];
        }

        return total;
    }

    function increaseTotalVoteTokenPerDay(
        uint128 _class,
        uint128 _nonce,
        uint256 _votingDay,
        uint256 _amountVoteTokens
    ) public onlyProposalLogic {
        totalVoteTokenPerDay[_class][_nonce][_votingDay] += _amountVoteTokens;
    }
 
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
        string memory _title,
        bytes32 _descriptionHash
    ) public onlyProposalLogic {
        require(_proposer != address(0), "GovStorage: zero address");

        proposal[_class][_nonce].startTime = _startTime;
        proposal[_class][_nonce].endTime = _endTime;
        proposal[_class][_nonce].proposer = _proposer;
        proposal[_class][_nonce].approvalMode = _approvalMode;
        proposal[_class][_nonce].targets = _targets;
        proposal[_class][_nonce].values = _values;
        proposal[_class][_nonce].calldatas = _calldatas;
        proposal[_class][_nonce].title = _title;
        proposal[_class][_nonce].descriptionHash = _descriptionHash;

        proposals.push(proposal[_class][_nonce]);
    }

    function getAllProposals() public view returns(Proposal[] memory) {
        return proposals;
    }

    function setProposalStatus(
        uint128 _class,
        uint128 _nonce,
        ProposalStatus _status
    ) public onlyGov {
        proposal[_class][_nonce].status = _status;
    }

    function getProposalNonce(
        uint128 _class
    ) public view returns(uint128) {
        return proposalNonce[_class];
    }

    function setProposalNonce(
        uint128 _class,
        uint128 _nonce
    ) public onlyGov {
        proposalNonce[_class] = _nonce;
    }

    /**
    * return the CDP of DGOV to DBIT
    */
    function cdpDGOVToDBIT() public view returns(uint256) {
        uint256 dgovTotalSupply = IDebondToken(getDGOVAddress()).getTotalCollateralisedSupply();

        return 100 ether + ((dgovTotalSupply / 33333)**2 / 1 ether);
    }

    /**
    * @notice the benchmark must be in 10^16 basis/ Ex: 5 * 10**16 = 5%
    */
    function setBenchmarkIR(uint256 _newBenchmarkInterestRate) external onlyExec {
        benchmarkInterestRate = _newBenchmarkInterestRate;
    }

    function setProposalThreshold(uint256 _newProposalThreshold) external onlyExec {
        _proposalThreshold = _newProposalThreshold;
    }

    function updateInterestRateAddress(address _interestRateAddress) external onlyExec {
        require(_interestRateAddress != address(0), "GovStorage: zero address");
        interestRatesContract = _interestRateAddress;
    }

    function updateExecutableAddress(address _executableAddress) external onlyExec {
        require(_executableAddress != address(0), "GovStorage: zero address");
        executable = _executableAddress;
    }

    function updateBankAddress(address _bankAddress) external onlyExec {
        require(_bankAddress != address(0), "GovStorage: zero address");
        bankContract = _bankAddress;
    }

    function updateExchangeAddress(address _exchangeAddress) external onlyExec {
        require(_exchangeAddress != address(0), "GovStorage: zero address");
        exchangeContract = _exchangeAddress;
    }

    function updateBankBondManagerAddress(address _bankBondManagerAddress) external onlyExec {
        require(_bankBondManagerAddress != address(0), "GovStorage: zero address");
        bankBondManagerContract = _bankBondManagerAddress;
    }

    function updateOracleAddress(address _oracleAddress) external onlyExec {
        require(_oracleAddress != address(0), "GovStorage: zero address");
        oracleContract = _oracleAddress;
    }

    function updateAirdropAddress(address _airdropAddress) external onlyExec {
        require(_airdropAddress != address(0), "GovStorage: zero address");
        airdropContract = _airdropAddress;
    }

    function updateGovernanceAddress(address _governanceAddress) external onlyExec {
        require(_governanceAddress != address(0), "GovStorage: zero address");
        governance = _governanceAddress;
    }

    function setFundSize(
        uint256 _newDBITBudgetPPM,
        uint256 _newDGOVBudgetPPM
    ) external onlyExec returns(bool) {
        dbitBudgetPPM = _newDBITBudgetPPM;
        dgovBudgetPPM = _newDGOVBudgetPPM;

        return true;
    }

    function setTeamAllocation(
        address _to,
        uint256 _newDBITPPM,
        uint256 _newDGOVPPM
    ) external onlyExec returns(bool) {
        require(_to != address(0), "Gov: zero address");
        require(
            checkSupply(_to, _newDBITPPM, _newDGOVPPM),
            "Executable: Fails, not enough supply"
        );

        allocatedToken[_to].dbitAllocationPPM = _newDBITPPM;
        allocatedToken[_to].dgovAllocationPPM = _newDGOVPPM;

        return true;
    }

    function setAllocatedToken(
        address _token,
        address _to,
        uint256 _amount
    ) external onlyExec {
        require(_to != address(0), "Gov: zero address");
        require(
            _checkSupply(_token, _to, _amount),
            "GovStorage: not enough supply"
        );

        if(_token == dbitContract) {
            allocatedToken[_to].allocatedDBITMinted += _amount;
            dbitTotalAllocationDistributed += _amount;
        }
        
        if (_token == dgovContract) {
            allocatedToken[_to].allocatedDGOVMinted += _amount;
            dgovTotalAllocationDistributed += _amount;
        }
    }

    function claimFundForProposal(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) public onlyExec returns(bool) {
        require(_to != address(0), "Gov: zero address");

        uint256 _dbitTotalSupply = IDebondToken(dbitContract).totalSupply();
        uint256 _dgovTotalSupply = IDebondToken(dgovContract).totalSupply();

        require(
            _amountDBIT <= (_dbitTotalSupply - dbitTotalAllocationDistributed) / 1e6 * 
                           (dbitBudgetPPM - dbitAllocationDistibutedPPM),
            "Gov: DBIT amount not valid"
        );
        require(
            _amountDGOV <= (_dgovTotalSupply - dgovTotalAllocationDistributed) / 1e6 * 
                           (dgovBudgetPPM - dgovAllocationDistibutedPPM),
            "Gov: DGOV amount not valid"
        );
        
        allocatedToken[_to].allocatedDBITMinted += _amountDBIT;
        dbitTotalAllocationDistributed += _amountDBIT;

        allocatedToken[_to].allocatedDGOVMinted += _amountDGOV;
        dgovTotalAllocationDistributed += _amountDGOV;

        return true;
    }

    function _checkSupply(
        address _token,
        address _account,
        uint256 _amount
    ) private view onlyDBITorDGOV(_token) returns(bool) {
        uint256 tokenAllocPPM;

        if(_token == dbitContract) {
            tokenAllocPPM = allocatedToken[_account].dbitAllocationPPM;
        }

        if(_token == dgovContract) {
            tokenAllocPPM = allocatedToken[_account].dgovAllocationPPM;
        }

        require(
            IDebondToken(
                _token
            ).getAllocatedBalance(_account) + _amount <=
            IDebondToken(
                _token
            ).getTotalCollateralisedSupply() * tokenAllocPPM / 1 ether,
            "Executable: Not enough token supply"
        );

        return true;
    }

    /**
    * @dev internal function to check DBIT and DGOV supply
    * @param _to the recipient in mintAllocatedToken and changeTeamAllocation
    * @param _amountDBIT amount of DBIT to mint or new DBIT allocation percentage
    * @param _amountDGOV amount of DGOV to mint or new DGOV allocation percentage
    */
    function checkSupply(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) public view returns(bool) {
        (
            uint256 dbitAllocPPM,
            uint256 dgovAllocPPM
        ) = getAllocatedToken(_to);
       
        require(
            IDebondToken(
                getDBITAddress()
            ).getAllocatedBalance(_to) + _amountDBIT <=
            IDebondToken(
                getDBITAddress()
            ).getTotalCollateralisedSupply() * dbitAllocPPM / 1 ether,
            "Executable: Not enough DBIT supply"
        );

        require(
            IDebondToken(
                getDGOVAddress()
            ).getAllocatedBalance(_to) + _amountDGOV <=
            IDebondToken(
                getDGOVAddress()
            ).getTotalCollateralisedSupply() * dgovAllocPPM / 1 ether,
            "Executable: Not enough DGOV supply"
        );

        return true;
    }
}