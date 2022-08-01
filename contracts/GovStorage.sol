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
import "./interfaces/IVoteCounting.sol";

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
    address public proposalLogicContract;
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

    modifier onlyDebondExecutor(address _executor) {
        require(
            _executor == getDebondTeamAddress(),
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

    modifier onlyProposalLogic {
        require(
            msg.sender == getProposalLogicContract()
        );
        _;
    }

    modifier onlyDebondContracts() {
        require(
            msg.sender == getGovernanceAddress() ||
            msg.sender == getExecutableContract() ||
            msg.sender == getProposalLogicContract()
        );
        _;
    }

    constructor(
        address _debondTeam,
        address _vetoOperator
    ) {
        _proposalThreshold = 10 ether;
        interestRateForStakingDGOV = 5;

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

    function setUpGoup1(
        address _governance,
        address _dgovContract,
        address _dbitContract,
        address _stakingContract,
        address _voteContract,
        address _voteCounting
    ) external onlyVetoOperator {
        governance = _governance;
        dgovContract = _dgovContract;
        dbitContract = _dbitContract;
        stakingContract = _stakingContract;
        voteTokenContract = _voteContract;
        voteCountingContract = _voteCounting;
    }

    function setUpGoup2(
        address _settingsContrats,
        address _proposalLogicContract,
        address _executable,
        address _bankContract,
        address _exchangeContract,
        address _exchangeStorageContract,
        address _airdropContract
    ) external onlyVetoOperator {
        govSettingsContract = _settingsContrats;
        proposalLogicContract = _proposalLogicContract;
        executable = _executable;
        exchangeContract = _bankContract;
        exchangeStorageContract = _exchangeStorageContract;
        bankContract = _exchangeContract;
        airdropContract = _airdropContract;
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


    function getThreshold() public view returns(uint256) {
        return _proposalThreshold;
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

    function getProposalLogicContract() public view returns(address) {
        return proposalLogicContract;
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
        string memory,
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
            _proposal.title,
            _proposal.descriptionHash
        );
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

        if (block.timestamp <= _proposal.startTime) {
            return ProposalStatus.Pending;
        }

        if (block.timestamp <= _proposal.endTime) {
            return ProposalStatus.Active;
        }

        if (_class == 2) {
            if (
                IVoteCounting(voteCountingContract).quorumReached(_class, _nonce) && 
                IVoteCounting(voteCountingContract).voteSucceeded(_class, _nonce)
            ) {
                return ProposalStatus.Succeeded;
            } else {
                return ProposalStatus.Defeated;
            }
        } else {
            if (IVoteCounting(voteCountingContract).vetoApproved(_class, _nonce)) {
                return ProposalStatus.Succeeded;
            } else {
                return ProposalStatus.Defeated;
            }
        }
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
    ) public onlyProposalLogic {
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
        string memory _title
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
    }

    function setProposalDescriptionHash(
        uint128 _class,
        uint128 _nonce,
        bytes32 _descriptionHash
    ) external onlyGov {
        proposal[_class][_nonce].descriptionHash = _descriptionHash;
    }

    function setProposalStatus(
        uint128 _class,
        uint128 _nonce,
        ProposalStatus _status
    ) public onlyDebondContracts {
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
    ) public onlyProposalLogic {
        proposalNonce[_class] = _nonce;
    }

    //==== FROM EXECUTABLE

    function updateGovernanceContract(
        address _newGovernanceAddress,
        address _executor
    ) public onlyExec returns(bool) {
        require(_newGovernanceAddress != address(0), "GovStorage: zero address");
        require(_executor != address(0), "GovStorage: zero address");

        governance = _newGovernanceAddress;

        return true;
    }

    function updateExchangeContract(
        address _newExchangeAddress,
        address _executor
    ) public onlyExec returns(bool) {
        require(_newExchangeAddress != address(0), "GovStorage: zero address");
        require(_executor != address(0), "GovStorage: zero address");

        exchangeContract = _newExchangeAddress;

        return true;
    }

    function updateBankContract(
        address _newBankAddress,
        address _executor
    ) public onlyExec returns(bool) {
        require(_newBankAddress != address(0), "GovStorage: zero address");
        require(_executor != address(0), "GovStorage: zero address");
        
        bankContract = _newBankAddress;

        return true;
    }

    function setBenchmarkIR(uint256 _newBenchmarkInterestRate) external onlyExec {
        benchmarkInterestRate = _newBenchmarkInterestRate;
    }

    function setFundSize(
        uint256 _newDBITBudgetPPM,
        uint256 _newDGOVBudgetPPM
    ) external onlyExec {
        dbitBudgetPPM = _newDBITBudgetPPM;
        dgovBudgetPPM = _newDGOVBudgetPPM;
    }

    function setTeamAllocation(
        address _to,
        uint256 _newDBITPPM,
        uint256 _newDGOVPPM
    ) external onlyExec {
        require(_to != address(0), "Gov: zero address");

        allocatedToken[_to].dbitAllocationPPM = _newDBITPPM;
        allocatedToken[_to].dgovAllocationPPM = _newDGOVPPM;
    }

    function mintAllocatedToken(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) public onlyExec {
        require(_to != address(0), "Gov: zero address");
        
        allocatedToken[_to].allocatedDBITMinted += _amountDBIT;
        dbitTotalAllocationDistributed += _amountDBIT;

        allocatedToken[_to].allocatedDGOVMinted += _amountDGOV;
        dgovTotalAllocationDistributed += _amountDGOV;
    }

    function claimFundForProposal(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) public onlyExec returns(bool) {
        require(_to != address(0), "Gov: zero address");

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