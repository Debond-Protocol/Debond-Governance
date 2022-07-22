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
import "./interfaces/IGovStorage.sol";

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

    struct VotingReward {
        uint256 numberOfVotingDays;
        uint256 numberOfDBITDistributedPerDay;
    }

    bool public initialized;

    address public debondOperator;
    address public debondTeam;
    address public governance;
    address public exchangeContract;
    address public exchangeStorageContract;
    address public bankContract;
    address public dgovContract;
    address public dbitContract;
    address public stakingContract;
    address public voteTokenContract;
    address public govSettingsContract;
    address public executable;
    address public voteCountingContract;
    address public airdropContract;

    address public vetoOperator;

    uint256 public dbitBudgetPPM;
    uint256 public dgovBudgetPPM;
    uint256 public dbitAllocationDistibutedPPM;
    uint256 public dgovAllocationDistibutedPPM;
    uint256 public dbitTotalAllocationDistributed;
    uint256 public dgovTotalAllocationDistributed;

    uint256 public benchmarkInterestRate;
    uint256 public interestRateForStakingDGOV;
    uint256 public _proposalThreshold;
    uint256 constant private NUMBER_OF_SECONDS_IN_YEAR = 31536000;

    mapping(uint128 => mapping(uint128 => Proposal)) proposal;
    mapping(address => AllocatedToken) allocatedToken;
    // link proposal class to class info
    mapping(uint128 => uint256[6]) public proposalClassInfo;
    // links proposal class to proposal nonce
    mapping(uint128 => uint128) public proposalNonce;
    // vote rewards info
    mapping(uint128 => VotingReward) public votingReward;
    // total vote tokens collected per day for a given proposal
    // key1: proposal class, key2: proposal nonce, key3: voting day (1, 2, 3, etc.)
    mapping(uint128 => mapping(uint128 => mapping(uint256 => uint256))) public totalVoteTokenPerDay;

    modifier onlyDebondOperator {
        require(msg.sender == debondOperator, "Gov: Need rights");
        _;
    }

    modifier onlyGov {
        require(
            msg.sender == getGovernanceAddress(),
            "Gov: Only Gouvernance"
        );
        _;
    }

    modifier onlyDebondExecutor(address _executor) {
        require(
            _executor == getDebondTeamAddress() ||
            _executor == getDebondOperator(),
            "Gov: can't execute this task"
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

    modifier onlyGovOrExec() {
        require(
            msg.sender == getGovernanceAddress() ||
            msg.sender == getExecutableContract()
        );
        _;
    }

    constructor(
        address _debondTeam,
        address _vetoOperator,
        address _debondOperator
    ) {
        _proposalThreshold = 10 ether;
        interestRateForStakingDGOV = 5;

        debondOperator = _debondOperator;
        debondTeam = _debondTeam;
        vetoOperator = _vetoOperator;

        // in percent
        benchmarkInterestRate = 5;

        dbitBudgetPPM = 1e5 * 1 ether;
        dgovBudgetPPM = 1e5 * 1 ether;

        allocatedToken[debondTeam].dbitAllocationPPM = 4e4 * 1 ether;
        allocatedToken[debondTeam].dgovAllocationPPM = 8e4 * 1 ether;

        // proposal class info
        proposalClassInfo[0][0] = 3;
        proposalClassInfo[0][1] = 50;
        proposalClassInfo[0][3] = 1;
        proposalClassInfo[0][4] = 1;

        proposalClassInfo[1][0] = 3;
        proposalClassInfo[1][1] = 50;
        proposalClassInfo[1][3] = 1;
        proposalClassInfo[1][4] = 1;

        proposalClassInfo[2][0] = 3;
        proposalClassInfo[2][1] = 50;
        proposalClassInfo[2][3] = 0;
        proposalClassInfo[2][4] = 120;

        // voting rewards by class
        votingReward[0].numberOfVotingDays = 3;
        votingReward[0].numberOfDBITDistributedPerDay = 5;

        votingReward[1].numberOfVotingDays = 3;
        votingReward[1].numberOfDBITDistributedPerDay = 5;

        votingReward[2].numberOfVotingDays = 1; // 3
        votingReward[2].numberOfDBITDistributedPerDay = 5;
    }

    function firstSetUp(
        address _governance,
        address _dgovContract,
        address _dbitContract,
        address _stakingContract,
        address _voteContract,
        address _voteCounting,
        address _settingsContrats,
        address _executable,
        address _bankContract,
        address _exchangeContract,
        address _exchangeStorageContract,
        address _airdropContract
    ) public onlyDebondOperator returns(bool) {
        require(!initialized, "Gov: Already initialized");

        governance = _governance;
        dgovContract = _dgovContract;
        dbitContract = _dbitContract;
        stakingContract = _stakingContract;
        voteTokenContract = _voteContract;
        voteCountingContract = _voteCounting;
        govSettingsContract = _settingsContrats;
        executable = _executable;
        exchangeContract = _bankContract;
        exchangeStorageContract = _exchangeStorageContract;
        bankContract = _exchangeContract;
        airdropContract = _airdropContract;

        return true;
    }

    function isInitialized() public view returns(bool) {
        return initialized;
    }

    function initializeDebond() public onlyDebondOperator returns(bool) {
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


    function getThreshold() public view returns(uint256) {
        return _proposalThreshold;
    }

    function getDebondOperator() public view returns(address) {
        return debondOperator;
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

    function getVoteTokenContract() public view returns(address) {
        return voteTokenContract;
    }

    function getGovSettingContract() public view returns(address) {
        return govSettingsContract;
    }

    function getAirdropContract() public view returns(address) {
        return airdropContract;
    }

    function getInterestForStakingDGOV() public view returns(uint256) {
        return interestRateForStakingDGOV;
    }

    function getNumberOfSecondInYear() public pure returns(uint256) {
        return NUMBER_OF_SECONDS_IN_YEAR;
    }

    function setThreshold(
        uint256 _newProposalThreshold,
        address _executor
    ) public onlyGov onlyDebondExecutor(_executor) {
        _proposalThreshold = _newProposalThreshold;
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

    function getVoteCountingAddress() public view returns(address) {
        return voteCountingContract;
    }

    function getDebondTeamAddress() public view returns(address) {
        return debondTeam;
    }

    function getBenchmarkIR() public view returns(uint256) {
        return benchmarkInterestRate;
    }

    function getBudget() public view returns(uint256, uint256) {
        return (dbitBudgetPPM, dgovBudgetPPM);
    }

    function getAllocationDistributed() public view returns(uint256, uint256) {
        return (dbitAllocationDistibutedPPM, dgovAllocationDistibutedPPM);
    }

    function getTotalAllocationDistributed() public view returns(uint256, uint256) {
        return (
            dbitTotalAllocationDistributed,
            dgovTotalAllocationDistributed
        );
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
    * @dev return the proposal class info for a given class and index
    * @param _class proposal class
    * @param _index index in the proposal class info array
    */
    function getProposalClassInfo(
        uint128 _class,
        uint256 _index
    ) public view returns(uint256) {
        return proposalClassInfo[_class][_index];
    }

    /**
    * @dev return a proposal
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function getProposal(
        uint128 _class,
        uint128 _nonce
    ) public view returns(
        uint256,
        uint256,
        address,
        ProposalStatus,
        ProposalApproval,
        address[] memory,
        uint256[] memory,
        bytes[] memory,
        bytes32
    ) {
        Proposal memory _proposal = proposal[_class][_nonce];

        return (
            _proposal.startTime,
            _proposal.endTime,
            _proposal.proposer,
            _proposal.status,
            _proposal.approvalMode,
            _proposal.targets,
            _proposal.values,
            _proposal.calldatas,
            _proposal.descriptionHash
        );
    }

    function getProposalInfoForExecutable(
        uint128 _class,
        uint128 _nonce
    ) public view returns(
        address,
        address[] memory,
        uint256[] memory,
        bytes[] memory
    ) {
        Proposal memory _proposal = proposal[_class][_nonce];

        return (
            _proposal.proposer,
            _proposal.targets,
            _proposal.values,
            _proposal.calldatas
        );
    }

    function getNumberOfVotingDays(
        uint128 _class
    ) public view returns(uint256) {
        return votingReward[_class].numberOfVotingDays;
    }

    function getTotalVoteTokenPerDay(
        uint128 _class,
        uint128 _nonce,
        uint256 _votingDay
    ) public view returns(uint256) {
        return totalVoteTokenPerDay[_class][_nonce][_votingDay];
    }

    function increaseTotalVoteTokenPerDay(
        uint128 _class,
        uint128 _nonce,
        uint256 _votingDay,
        uint256 _amountVoteTokens
    ) public onlyGov {
        totalVoteTokenPerDay[_class][_nonce][_votingDay] += _amountVoteTokens;
    }

    function getNumberOfDBITDistributedPerDay(
        uint128 _class
    ) public view returns(uint256) {
        return votingReward[_class].numberOfDBITDistributedPerDay;
    }
 
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
    ) public onlyGov {
        proposal[_class][_nonce].startTime = _startTime;
        proposal[_class][_nonce].endTime = _endTime;
        proposal[_class][_nonce].proposer = _proposer;
        proposal[_class][_nonce].approvalMode = _approvalMode;
        proposal[_class][_nonce].targets = _targets;
        proposal[_class][_nonce].values = _values;
        proposal[_class][_nonce].calldatas = _calldatas;
        proposal[_class][_nonce].descriptionHash = keccak256(bytes(_description));
    }

    function setProposalStatus(
        uint128 _class,
        uint128 _nonce,
        ProposalStatus _status
    ) public onlyGovOrExec {
        proposal[_class][_nonce].status = _status;
    }

    /**
    * @dev set a proposal class info for a given class and index
    * @param _class proposal class
    * @param _index index in the proposal class info array
    * @param _value the new ven value of the proposal class info
    */
    function setProposalClassInfo(
        uint128 _class,
        uint256 _index,
        uint256 _value
    ) public onlyGov {
        proposalClassInfo[_class][_index] = _value;
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

    //==== FROM EXECUTABLE

    function updateGovernanceContract(
        address _newGovernanceAddress,
        address _executor
    ) public onlyExec returns(bool) {
        require(_executor != address(0));
        governance = _newGovernanceAddress;

        return true;
    }

    function updateExchangeContract(
        address _newExchangeAddress,
        address _executor
    ) public onlyExec returns(bool) {
        require(_executor != address(0));
        exchangeContract = _newExchangeAddress;

        return true;
    }

    function updateBankContract(
        address _newBankAddress,
        address _executor
    ) public onlyExec returns(bool) {
        require(_executor != address(0));
        bankContract = _newBankAddress;

        return true;
    }

    function updateBenchmarkIR(
        uint256 _newBenchmarkInterestRate,
        address _executor
    ) public onlyExec returns(bool) {
        require(_executor != address(0));
        benchmarkInterestRate = _newBenchmarkInterestRate;

        return true;
    }

    function changeCommunityFundSize(
        uint256 _newDBITBudgetPPM,
        uint256 _newDGOVBudgetPPM,
        address _executor
    ) public onlyExec returns(bool) {
        require(_executor != address(0));
        dbitBudgetPPM = _newDBITBudgetPPM;
        dgovBudgetPPM = _newDGOVBudgetPPM;

        return true;
    }

    function changeTeamAllocation(
        address _to,
        uint256 _newDBITPPM,
        uint256 _newDGOVPPM,
        address _executor
    ) public onlyExec returns(bool) {
        require(_executor != address(0));
        AllocatedToken memory _allocatedToken = allocatedToken[_to];
        uint256 dbitAllocDistributedPPM = dbitAllocationDistibutedPPM;
        uint256 dgovAllocDistributedPPM = dgovAllocationDistibutedPPM;

        require(
            dbitAllocDistributedPPM - _allocatedToken.dbitAllocationPPM + _newDBITPPM <= dbitBudgetPPM,
            "Gov: too much"
        );

        require(
            dgovAllocDistributedPPM - _allocatedToken.dgovAllocationPPM + _newDGOVPPM <= dgovBudgetPPM,
            "Gov: too much"
        );

        dbitAllocationDistibutedPPM = dbitAllocDistributedPPM - allocatedToken[_to].dbitAllocationPPM + _newDBITPPM;
        allocatedToken[_to].dbitAllocationPPM = _newDBITPPM;

        dgovAllocationDistibutedPPM = dgovAllocDistributedPPM - allocatedToken[_to].dgovAllocationPPM + _newDGOVPPM;
        allocatedToken[_to].dgovAllocationPPM = _newDGOVPPM;

        return true;
    }

    function mintAllocatedToken(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV,
        address _executor
    ) public onlyExec returns(bool) {
        require(_executor != address(0));
        AllocatedToken memory _allocatedToken = allocatedToken[_to];
        
        uint256 _dbitCollaterizedSupply = IDebondToken(dbitContract).getTotalCollateralisedSupply();
        uint256 _dgovCollaterizedSupply = IDebondToken(dgovContract).getTotalCollateralisedSupply();
        
        require(
            IDebondToken(dbitContract).getAllocatedBalance(_to) + _amountDBIT <=
            _dbitCollaterizedSupply * _allocatedToken.dbitAllocationPPM / 1 ether,
            "Gov: not enough supply"
        );
        require(
            IDebondToken(dgovContract).getAllocatedBalance(_to) + _amountDGOV <=
            _dgovCollaterizedSupply * _allocatedToken.dgovAllocationPPM / 1 ether,
            "Gov: not enough supply"
        );
        
        allocatedToken[_to].allocatedDBITMinted += _amountDBIT;
        dbitTotalAllocationDistributed += _amountDBIT;

        allocatedToken[_to].allocatedDGOVMinted += _amountDGOV;
        dgovTotalAllocationDistributed += _amountDGOV;

        return true;
    }

    function claimFundForProposal(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) public onlyExec returns(bool) {
        uint256 _dbitTotalSupply = IDebondToken(dbitContract).totalSupply();
        uint256 _dgovTotalSupply = IDebondToken(dgovContract).totalSupply();

        // NEED TO CHECK THIS WITH YU (see first param on require)
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
}