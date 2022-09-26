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

contract GovStorage is IGovStorage {
    mapping(uint128 => uint256) numberOfVotingDays;
    mapping(uint128 => uint128) public proposalNonce;
    mapping(address => uint256) public stakingCounter;
    mapping(address => AllocatedToken) allocatedToken;
    mapping(uint128 => uint256) private _votingPeriod;
    mapping(address => StackedDGOV[]) _totalStackedDGOV;
    mapping(uint128 =>  uint256) private _proposalQuorum;
    mapping(uint128 => mapping(uint128 => Proposal)) proposal;
    mapping(uint256 => VoteTokenAllocation) private voteTokenAllocation;
    mapping(address => mapping(uint256 => StackedDGOV)) internal stackedDGOV;
    mapping(uint128 => mapping(uint128 => UserVoteData[])) public userVoteData;
    mapping(uint128 => mapping(uint128 => ProposalVote)) internal _proposalVotes;
    mapping(uint128 => mapping(uint128 => mapping(uint256 => uint256))) public totalVoteTokenPerDay;

    bool public initialized;

    address public debondTeam;
    address public governance;
    address public executable;
    address public apmContract;
    address public dgovContract;
    address public dbitContract;
    address public bankContract;
    address public vetoOperator;
    address public stakingContract;
    address public erc3475Contract;
    address public exchangeContract;
    address public bankDataContract;
    address public voteTokenContract;
    address public governanceMigrator;
    address public exchangeStorageContract;
    address public bankBondManagerContract;

    uint256 _lockGroup1;
    uint256 _lockGroup2;
    uint256 public dbitBudgetPPM;
    uint256 public dgovBudgetPPM;
    uint256 private _proposalThreshold;
    uint256 public benchmarkInterestRate;
    uint256 public minimumStakingDuration;
    uint256 public dbitAllocationDistibutedPPM;
    uint256 public dgovAllocationDistibutedPPM;
    uint256 public dbitTotalAllocationDistributed;
    uint256 public dgovTotalAllocationDistributed;
    uint256 constant private NUMBER_OF_SECONDS_IN_YEAR = 31536000;

    Proposal[] proposals;
    VoteTokenAllocation[] private _voteTokenAllocation;

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

    modifier onlyStaking {
        require(
            msg.sender == getStakingContract(),
            "Gov: only staking contract"
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

        // to define during deployment
        _votingPeriod[0] = 2;
        _votingPeriod[1] = 2;
        _votingPeriod[2] = 2;

        // voting rewards by class
        numberOfVotingDays[0] = 1;
        numberOfVotingDays[1] = 1;
        numberOfVotingDays[2] = 1;
        minimumStakingDuration = 10;

        // Staking
        // for tests only
        voteTokenAllocation[0].duration = 4;
        voteTokenAllocation[0].allocation = 10000000000000000;

        //voteTokenAllocation[0].duration = 4 weeks;
        //voteTokenAllocation[0].allocation = 3000000000000000;
        _voteTokenAllocation.push(voteTokenAllocation[0]);

        voteTokenAllocation[1].duration = 12 weeks;
        voteTokenAllocation[1].allocation = 3653793637913968;
        _voteTokenAllocation.push(voteTokenAllocation[1]);

        voteTokenAllocation[2].duration = 24 weeks;
        voteTokenAllocation[2].allocation = 4578397467645146;
        _voteTokenAllocation.push(voteTokenAllocation[2]);

        voteTokenAllocation[3].duration = 48 weeks;
        voteTokenAllocation[3].allocation = 5885984743473081;
        _voteTokenAllocation.push(voteTokenAllocation[3]);

        voteTokenAllocation[4].duration = 96 weeks;
        voteTokenAllocation[4].allocation = 7735192402935436;
        _voteTokenAllocation.push(voteTokenAllocation[4]);

        voteTokenAllocation[5].duration = 144 weeks;
        voteTokenAllocation[5].allocation = 10000000000000000;
        _voteTokenAllocation.push(voteTokenAllocation[5]);
    }

    function setUpGroup1(
        address _governance,
        address _dgovContract,
        address _dbitContract,
        address _apmContract,
        address _bankBondManagerContract,
        address _stakingContract,
        address _voteContract
    ) external onlyVetoOperator {
        require(_lockGroup1 == 0, "GovStorage: Group1 already set");

        governance = _governance;
        dgovContract = _dgovContract;
        dbitContract = _dbitContract;
        apmContract = _apmContract;
        bankBondManagerContract = _bankBondManagerContract;
        stakingContract = _stakingContract;
        voteTokenContract = _voteContract;

        _lockGroup1 == 1;
    }

    function setUpGroup2(
        address _executable,
        address _bankContract,
        address _bankDataContract,
        address _erc3475Contract,
        address _exchangeContract,
        address _exchangeStorageContract
    ) external onlyVetoOperator {
        require(_lockGroup2 == 0, "GovStorage: Group2 already set");

        executable = _executable;
        bankContract = _bankContract;
        bankDataContract = _bankDataContract;
        erc3475Contract = _erc3475Contract;
        exchangeContract = _exchangeContract;
        exchangeStorageContract = _exchangeStorageContract;

        _lockGroup2 == 1;
    }

    function isInitialized() public view returns(bool) {
        return initialized;
    }

    function _generateNewNonce(uint128 _class) private returns(uint128 nonce) {
        nonce = proposalNonce[_class] + 1;
        proposalNonce[_class] = nonce;
    }

    function getProposaLastNonce(uint128 _class) public view returns(uint128) {
        return proposalNonce[_class];
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

    function getVoteTokenContract() public view returns(address) {
        return voteTokenContract;
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

    function getAllocatedToken(address _account) public view returns(uint256 dbitAllocPPM, uint256 dgovAllocPPM) {
        dbitAllocPPM = allocatedToken[_account].dbitAllocationPPM;
        dgovAllocPPM = allocatedToken[_account].dgovAllocationPPM;
    }

    function getAllocatedTokenMinted(address _account) public view returns(uint256 dbitAllocMinted, uint256 dgovAllocMinted) {
        dbitAllocMinted = allocatedToken[_account].allocatedDBITMinted;
        dgovAllocMinted = allocatedToken[_account].allocatedDGOVMinted;
    }

    function getProposalStruct(
        uint128 _class,
        uint128 _nonce
    ) public view returns(Proposal memory) {
        return proposal[_class][_nonce];
    }

    function getProposalProposer(
        uint128 _class,
        uint128 _nonce
    ) public view returns(address) {
        return proposal[_class][_nonce].proposer;
    }

    function getClassQuorum(uint128 _class) public view returns(uint256) {
        return _proposalQuorum[_class];
    }

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

        if(!voteSucceeded(_class, _nonce)) {
            return ProposalStatus.Defeated;
        } else {
            if(!quorumReached(_class, _nonce)) {
                return ProposalStatus.Defeated;
            } else {
                if(!vetoed(_class, _nonce)) {
                    return ProposalStatus.Defeated;
                } else {
                    return ProposalStatus.Succeeded;
                }
            }
        }
    }

    function quorumReached(
        uint128 _class,
        uint128 _nonce
    ) public view returns(bool reached) {
        ProposalVote storage proposalVote = _proposalVotes[_class][_nonce];

        reached =  proposalVote.forVotes + proposalVote.abstainVotes >= _quorum(_class, _nonce);
    }

    function voteSucceeded(
        uint128 _class,
        uint128 _nonce
    ) public view returns(bool succeeded) {
        ProposalVote storage proposalVote = _proposalVotes[_class][_nonce];

        succeeded = proposalVote.forVotes > proposalVote.againstVotes;
    }

    function _quorum(
        uint128 _class,
        uint128 _nonce
    ) public view returns(uint256 proposalQuorum) {
        ProposalVote storage proposalVote = _proposalVotes[_class][_nonce];

        uint256 minApproval = _proposalQuorum[_class];

        proposalQuorum =  minApproval * (
            proposalVote.forVotes +
            proposalVote.againstVotes +
            proposalVote.abstainVotes
        ) / 100;
    }

    function vetoed(
        uint128 _class,
        uint128 _nonce
    ) public view returns(bool) {
        return _proposalVotes[_class][_nonce].vetoed;
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

    function _increaseTotalVoteTokenPerDay(
        uint128 _class,
        uint128 _nonce,
        uint256 _votingDay,
        uint256 _amountVoteTokens
    ) private {
        totalVoteTokenPerDay[_class][_nonce][_votingDay] += _amountVoteTokens;
    }

    function getVotingPeriod(uint128 _class) public view returns(uint256) {
        return _votingPeriod[_class];
    }
 
    function setProposal(
        uint128 _class,
        address _proposer,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _title,
        bytes32 _descriptionHash
    ) public onlyGov returns(uint128 nonce) {
        require(_proposer != address(0), "GovStorage: zero address");

        nonce = _generateNewNonce(_class);
        ProposalApproval approval = getApprovalMode(_class);
        uint256 start = block.timestamp;
        uint256 end = start + getVotingPeriod(_class);

        proposal[_class][nonce].startTime = start;
        proposal[_class][nonce].endTime = end;
        proposal[_class][nonce].proposer = _proposer;
        proposal[_class][nonce].approvalMode = approval;
        proposal[_class][nonce].targets = _targets;
        proposal[_class][nonce].ethValues = _values;
        proposal[_class][nonce].calldatas = _calldatas;
        proposal[_class][nonce].title = _title;
        proposal[_class][nonce].descriptionHash = _descriptionHash;

        proposals.push(proposal[_class][nonce]);
    }

    function getAllProposals() public view returns(Proposal[] memory) {
        return proposals;
    }

    function setProposalStatus(
        uint128 _class,
        uint128 _nonce,
        ProposalStatus _status
    ) public onlyGov returns(Proposal memory) {
        proposal[_class][_nonce].status = _status;

        return proposal[_class][_nonce];
    }

    function cancel(
        uint128 _class,
        uint128 _nonce,
        address _proposer
    ) public onlyGov {
        ProposalStatus status = getProposalStatus(_class, _nonce);
        require(
            status != ProposalStatus.Canceled &&
            status != ProposalStatus.Executed
        );
        require(_proposer == proposal[_class][_nonce].proposer, "Gov: permission denied");

        proposal[_class][_nonce].status = ProposalStatus.Canceled;
    }

    function cdpDGOVToDBIT() public view returns(uint256) {
        uint256 dgovTotalSupply = IDebondToken(getDGOVAddress()).getTotalCollateralisedSupply();

        return 100 ether + ((dgovTotalSupply / 33333)**2 / 1 ether);
    }

    function getUserStake(address _staker, uint256 _stakingCounter) public view returns(StackedDGOV memory) {
        return stackedDGOV[_staker][_stakingCounter];
    }

    function updateStake(
        address _staker,
        uint256 _stakingCounter
    ) public onlyStaking returns(uint256 amountDGOV, uint256 amountVote) {
        StackedDGOV storage _staked = stackedDGOV[_staker][_stakingCounter];

        amountDGOV = _staked.amountDGOV;
        amountVote = _staked.amountVote;
        _staked.amountDGOV = 0;
        _staked.amountVote = 0;
    }

    function getStakedDGOVOf(address _account) public view returns(StackedDGOV[] memory) {
        return _totalStackedDGOV[_account];
    }

    function getVoteTokenAllocation() public view returns(VoteTokenAllocation[] memory) {
        return _voteTokenAllocation;
    }

    function getAvailableVoteTokens(
        address _staker,
        uint256 _stakingCounter
    ) external view returns(uint256 _voteTokens) {
        _voteTokens = stackedDGOV[_staker][_stakingCounter].amountVote;
    }

    function updateLastTimeInterestWithdraw(
        address _staker,
        uint256 _stakingCounter
    ) external onlyStaking {
        StackedDGOV memory _staked = stackedDGOV[_staker][_stakingCounter];
        require(_staked.amountDGOV > 0, "Staking: no DGOV staked");

        require(
            block.timestamp >= _staked.lastInterestWithdrawTime &&
            block.timestamp < _staked.startTime + _staked.duration,
            "Staking: Unstake DGOV to withdraw interest"
        );

        stackedDGOV[_staker][_stakingCounter].lastInterestWithdrawTime = block.timestamp;
    }

    function setVote(
        uint128 _class,
        uint128 _nonce,
        address _voter,
        uint8 _userVote,
        uint256 _amountVoteTokens
    ) public onlyGov {
        uint256 day = _getVotingDay(_class, _nonce);    
        _increaseTotalVoteTokenPerDay(_class, _nonce, day, _amountVoteTokens);
        _setVotingDay(_class, _nonce, _voter, day);
        _countVote(_class, _nonce, _voter, _userVote, _amountVoteTokens);
    }

    function setVeto(
        uint128 _class,
        uint128 _nonce,
        bool _vetoed
    ) public onlyGov {        
        _proposalVotes[_class][_nonce].vetoed = _vetoed;
    }

    function hasVoted(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) public view returns(bool voted) {
        voted = _proposalVotes[_class][_nonce].user[_account].hasVoted;
    }

    function getUsersVoteData(
        uint128 _class,
        uint128 _nonce
    ) public view returns(UserVoteData[] memory) {
        return userVoteData[_class][_nonce];
    }

    function numberOfVoteTokens(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) public view returns(uint256 amountTokens) {
        amountTokens = _proposalVotes[_class][_nonce].user[_account].weight;
    }

    function getUserVoteData(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) public view returns(
        bool,
        bool,
        uint256,
        uint256
    ) {
        return (
            _proposalVotes[_class][_nonce].user[_account].hasVoted,
            _proposalVotes[_class][_nonce].user[_account].hasBeenRewarded,
            _proposalVotes[_class][_nonce].user[_account].weight,
            _proposalVotes[_class][_nonce].user[_account].votingDay
        );
    }

    function getProposalVotes(
        uint128 _class,
        uint128 _nonce
    ) public view returns(uint256 forVotes, uint256 againstVotes, uint256 abstainVotes) {
        ProposalVote storage proposalVote = _proposalVotes[_class][_nonce];

        (forVotes, againstVotes, abstainVotes) = 
        (
            proposalVote.forVotes,
            proposalVote.againstVotes,
            proposalVote.abstainVotes
        );
    }

    function _getVotingDay(uint128 _class, uint128 _nonce) internal view returns(uint256 day) {
        Proposal memory _proposal = proposal[_class][_nonce];
        uint256 duration = _proposal.startTime > block.timestamp ?
            0: block.timestamp - _proposal.startTime;
        
        day = (duration / NUMBER_OF_SECONDS_IN_YEAR) + 1;
    }

    function _setVotingDay(
        uint128 _class,
        uint128 _nonce,
        address _voter,
        uint256 _day
    ) private {
        require(_voter != address(0), "VoteCounting: zero address");
        _proposalVotes[_class][_nonce].user[_voter].votingDay = _day;
    }

    function _countVote(
        uint128 _class,
        uint128 _nonce,
        address _account,
        uint8 _vote,
        uint256 _weight
    ) private {
        require(_account != address(0), "VoteCounting: zero address");
        ProposalVote storage proposalVote = _proposalVotes[_class][_nonce];
        require(
            !proposalVote.user[_account].hasVoted,
            "VoteCounting: already voted"
        );

        proposalVote.user[_account].hasVoted = true;
        proposalVote.user[_account].weight = _weight;

        if (_vote == uint8(VoteType.For)) {
            proposalVote.forVotes += _weight;
        } else if (_vote == uint8(VoteType.Against)) {
            proposalVote.againstVotes += _weight;
        } else if (_vote == uint8(VoteType.Abstain)) {
            proposalVote.abstainVotes += _weight;
        } else {
            revert("VoteCounting: invalid vote");
        }

        userVoteData[_class][_nonce].push(
            UserVoteData(
                {
                    voter: _account,
                    weight: _weight,
                    vote: _vote
                }
            )
        );
    }

    function hasBeenRewarded(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) public view returns(bool) {
        return _proposalVotes[_class][_nonce].user[_account].hasBeenRewarded;
    }

    function setUserHasBeenRewarded(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) public onlyStaking {
        _proposalVotes[_class][_nonce].user[_account].hasBeenRewarded = true;
    }

    function getVoteWeight(
        uint128 _class,
        uint128 _nonce,
        address _account
    ) public view returns(uint256) {
        return _proposalVotes[_class][_nonce].user[_account].weight;
    }

    function getApprovalMode(
        uint128 _class
    ) public pure returns(ProposalApproval unsassigned) {
        if (_class == 0 || _class == 1) {
            return ProposalApproval.Approve;
        }

        if (_class == 2) {
            return ProposalApproval.NoVote;
        }
    }

    function getStakingData(
        address _staker,
        uint256 _stakingCounter
    ) public view returns(
        uint256 _stakedAmount,
        uint256 startTime,
        uint256 duration,
        uint256 lastWithdrawTime
    ) {
        return (
            stackedDGOV[_staker][_stakingCounter].amountDGOV,
            stackedDGOV[_staker][_stakingCounter].startTime,
            stackedDGOV[_staker][_stakingCounter].duration,
            stackedDGOV[_staker][_stakingCounter].lastInterestWithdrawTime
        );
    }

    function setStakedData(
        address _staker,
        uint256 _amount,
        uint256 _durationIndex
    ) external onlyStaking returns(uint256 duration, uint256 _amountToMint) {
        uint256 counter = stakingCounter[_staker]; 

        stackedDGOV[_staker][counter + 1].startTime = block.timestamp;
        stackedDGOV[_staker][counter + 1].lastInterestWithdrawTime = block.timestamp;
        stackedDGOV[_staker][counter + 1].duration = voteTokenAllocation[_durationIndex].duration;
        stackedDGOV[_staker][counter + 1].amountDGOV += _amount;
        stackedDGOV[_staker][counter + 1].amountVote += _amount * voteTokenAllocation[_durationIndex].allocation / 10**16;
        stakingCounter[_staker] = counter + 1;

        _totalStackedDGOV[_staker].push(stackedDGOV[_staker][counter + 1]);

        _amountToMint = _amount * voteTokenAllocation[_durationIndex].allocation / 10**16;
        duration = voteTokenAllocation[_durationIndex].duration;
    }

    //============= For executable
    function setBenchmarkIR(uint256 _newBenchmarkInterestRate) external onlyExec {
        benchmarkInterestRate = _newBenchmarkInterestRate;
    }

    function setProposalThreshold(uint256 _newProposalThreshold) external onlyExec {
        _proposalThreshold = _newProposalThreshold;
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
