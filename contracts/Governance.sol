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

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./GovStorage.sol";
import "./utils/VoteCounting.sol";
import "./interfaces/IVoteToken.sol";
import "./interfaces/IGovSettings.sol";
import "./interfaces/IStaking.sol";
import "./interfaces/IExecutable.sol";
import "./interfaces/IGovernance.sol";
import "./test/DBIT.sol";
import "./Pausable.sol";

/**
* @author Samuel Gwlanold Edoumou (Debond Organization)
*/
contract Governance is GovStorage, VoteCounting, IExecutable, ReentrancyGuard, Pausable {
    /**
    * @dev governance constructor
    * @param _debondTeam account address of Debond team
    */
    constructor(address _debondTeam, address _vetoOperator) {
        debondTeam = _debondTeam;
        vetoOperator = _vetoOperator;
        debondOperator = _msgSender();

        dbitBudgetPPM = 1e5 * 1 ether;
        dgovBudgetPPM = 1e5 * 1 ether;
        allocatedToken[debondTeam].dbitAllocationPPM = 4e4 * 1 ether;
        allocatedToken[debondTeam].dgovAllocationPPM = 8e4 * 1 ether;

        // in percent
        benchmarkInterestRate = 5;
        // in percent
        interestRateForStakingDGOV = 5;

        // proposal threshold for proposer
        _proposalThreshold = 10 ether;

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

    /**
    * @dev see {INewGovernance} for description
    * @param _class proposal class
    * @param _targets array of contract to interact with if the proposal passes
    * @param _values array contraining ethers to send (can be array of zeros)
    * @param _calldatas array of encoded functions to call if the proposal passes
    * @param _description proposal description
    * @param nonce proposl nonce
    */
    function createProposal(
        uint128 _class,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    ) public override returns(uint128 nonce) {
        require(
            IVoteToken(voteTokenContract).availableBalance(_msgSender()) >= _proposalThreshold,
            "Gov: insufficient vote tokens"
        );

        require(
            _targets.length == _values.length &&
            _values.length == _calldatas.length,
            "Gov: invalid proposal"
        );

        nonce = _generateNewNonce(_class);
        ProposalApproval approval = getApprovalMode(_class);

        uint256 _start = block.timestamp + IGovSettings(govSettingsContract).votingDelay();
        uint256 _end = _start + IGovSettings(govSettingsContract).votingPeriod();

        proposal[_class][nonce].startTime = _start;
        proposal[_class][nonce].endTime = _end;
        proposal[_class][nonce].proposer = _msgSender();
        proposal[_class][nonce].approvalMode = approval;
        proposal[_class][nonce].targets = _targets;
        proposal[_class][nonce].values = _values;
        proposal[_class][nonce].calldatas = _calldatas;
        proposal[_class][nonce].descriptionHash = keccak256(bytes(_description));

        emit ProposalCreated(
            _class,
            nonce,
            _start,
            _end,
            _msgSender(),
            _targets,
            _values,
            _calldatas,
            _description,
            approval
        );
    }

    /**
    * @dev execute a proposal
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function executeProposal(
        uint128 _class,
        uint128 _nonce
    ) public override returns(bool) {
        require(_class >= 0 && _nonce > 0, "Gov: invalid proposal");

        Proposal storage _proposal = proposal[_class][_nonce];

        require(
            _msgSender() == _proposal.proposer,
            "Gov: permission denied"
        );

        ProposalStatus status = getProposalStatus(
            _class,
            _nonce
        );

        require(
            status == ProposalStatus.Succeeded,
            "Gov: proposal not successful"
        );

        proposal[_class][_nonce].status = ProposalStatus.Executed;

        emit ProposalExecuted(_class, _nonce);

        _execute(_proposal.targets, _proposal.values, _proposal.calldatas);

        return true;
    }

    /**
    * @dev execute a proposal
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function cancelProposal(
        uint128 _class,
        uint128 _nonce
    ) public {
        ProposalStatus status = getProposalStatus(
            _class,
            _nonce
        );

        require(
            status != ProposalStatus.Canceled &&
            status != ProposalStatus.Executed
        );

        proposal[_class][_nonce].status = ProposalStatus.Canceled;
    }
    
    /**
    * @dev internal execution mechanism
    * @param _targets array of contract to interact with
    * @param _values array contraining ethers to send (can be array of zeros)
    * @param _calldatas array of encoded functions
    */
    function _execute(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas
    ) internal virtual {
        string memory errorMessage = "Gov: call reverted without message";

        for (uint256 i = 0; i < _targets.length; i++) {
            (
                bool success,
                bytes memory data
            ) = _targets[i].call{value: _values[i]}(_calldatas[i]);

            Address.verifyCallResult(success, data, errorMessage);
        }
    }

    /**
    * @dev vote for a proposal
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _tokenOwner owner of staked dgov (can delagate their vote)
    * @param _userVote vote type: 0-FOR, 1-AGAINST, 2-ABSTAIN
    * @param _amountVoteTokens amount of vote tokens
    * @param _stakingCounter counter that returns the rank of staking dGoV
    */
    function vote(
        uint128 _class,
        uint128 _nonce,
        address _tokenOwner,
        uint8 _userVote,
        uint256 _amountVoteTokens,
        uint256 _stakingCounter
    ) public {
        address voter = _msgSender();

        require(_class >= 0 && _nonce > 0, "Gov: invalid proposal");

        uint256 _dgovStaked = IStaking(stakingContract).getStakedDGOV(_tokenOwner, _stakingCounter);
        uint256 approvedToSpend = IERC20(dgovContract).allowance(_tokenOwner, voter);

        require(
            _amountVoteTokens <= _dgovStaked &&
            _amountVoteTokens <= approvedToSpend,
            "Gov: not approved or not enough dGoV staked"
        );

        require(
            _amountVoteTokens <= 
            IERC20(voteTokenContract).balanceOf(_tokenOwner) - 
            IVoteToken(voteTokenContract).lockedBalanceOf(_tokenOwner, _class, _nonce),
            "Gov: not enough vote tokens"
        );

        IVoteToken(voteTokenContract).lockTokens(_tokenOwner, voter, _amountVoteTokens, _class, _nonce);

        _vote(_class, _nonce, voter, _userVote, _amountVoteTokens);
    }

    /**
    * @dev veto the proposal
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _approval veto type, yes if should pass, false otherwise
    */
    function veto(
        uint128 _class,
        uint128 _nonce,
        bool _approval
    ) public {
        require(_msgSender() == vetoOperator, "Gov: permission denied");
        require(_class >= 0 && _nonce > 0, "Gov: invalid proposal");
        require(
            getProposalStatus(_class, _nonce) == ProposalStatus.Active,
            "Gov: vote not active"
        );

        if (_approval == true) {
            _proposalVotes[_class][_nonce].vetoApproval = 1;
        } else {
            _proposalVotes[_class][_nonce].vetoApproval = 2;
        }
    }

    /**
    * @dev stake DGOV tokens
    * @param _amount amount of DGOV to stake
    * @param _duration staking duration
    * @param staked true if DGOV tokens have been staked successfully, false otherwise
    */
    function stakeDGOV(
        uint256 _amount,
        uint256 _duration
    ) public returns(bool staked) {
        address staker = _msgSender();

        IStaking(stakingContract).stakeDgovToken(staker, _amount, _duration);

        staked = true;
    }

    /**
    * @dev unstake DGOV tokens
    * @param _stakingCounter counter that returns the rank of staking dGoV
    * @param unstaked true if DGOV tokens have been unstaked successfully, false otherwise
    */
    function unstakeDGOV(
        uint256 _stakingCounter
    ) public returns(bool unstaked) {
        address staker = _msgSender();

        uint256 amountStaked = IStaking(stakingContract).unstakeDgovToken(
            staker,
            _stakingCounter
        );

        // the interest calculated from this function is in ether unit
        uint256 interest = IStaking(stakingContract).calculateInterestEarned(
            staker,
            _stakingCounter,
            interestRateForStakingDGOV
        );

        // CHECK WITH YU THE ORIGIN OF DBIT TO TRANSFER
        // ToDo: CHAGE THIS
        // transfer DBIT interests to the staker - the interest is in ether unit
        //IERC20(dbitContract).transferFrom(dbitContract, staker, amountStaked * interest / 1 ether);
        IERC20(dbitContract).transfer(staker, amountStaked * interest / 1 ether);

        unstaked = true;
    }

    /**
    * @dev redeem vote tokens and get DBIT rewards
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function unlockVoteTokens(
        uint128 _class,
        uint128 _nonce
    ) external {
        address tokenOwner = _msgSender();

        require(
            block.timestamp > proposal[_class][_nonce].endTime,
            "Gov: still voting"
        );
        require(
            hasVoted(_class, _nonce, tokenOwner),
            "Gov: you haven't voted"
        );
        
        uint256 _amount = IVoteToken(voteTokenContract).lockedBalanceOf(tokenOwner, _class, _nonce);
        _unlockVoteTokens(_class, _nonce, tokenOwner, _amount);

        // transfer the rewards earned for this vote
        _transferDBITInterest(_class, _nonce, tokenOwner);
    }

    /**
    * @dev transfer DBIT interest earned by voting for a proposal
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _tokenOwner owner of stacked dgov
    */ 
    function _transferDBITInterest(
        uint128 _class,
        uint128 _nonce,
        address _tokenOwner
    ) internal {
        ProposalVote storage proposalVote = _proposalVotes[_class][_nonce];

        require(
            proposalVote.user[_tokenOwner].hasBeenRewarded == false,
            "Gov: already rewarded"
        );
        proposalVote.user[_tokenOwner].hasBeenRewarded = true;

        uint256 _reward;
        
        for(uint256 i = 1; i <= votingReward[_class].numberOfVotingDays; i++) {
            _reward += (1 ether * 1 ether) / totalVoteTokenPerDay[_class][_nonce][i];
        }

        _reward = _reward * proposalVote.user[_tokenOwner].weight * votingReward[_class].numberOfDBITDistributedPerDay / 1 ether;

        IERC20(dbitContract).transfer(_tokenOwner, _reward);
    }

    /**
    * @dev internal unlockVoteTokens function
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _tokenOwner owner of vote tokens
    * @param _amount amount of vote tokens to unlock
    */
    function _unlockVoteTokens(
        uint128 _class,
        uint128 _nonce,
        address _tokenOwner,
        uint256 _amount
    ) internal {
        IVoteToken(voteTokenContract).unlockTokens(_tokenOwner, _amount, _class, _nonce);
    }

    /**
    * @dev internal vote function
    */
    function _vote(
        uint128 _class,
        uint128 _nonce,
        address _voter,
        uint8 _userVote,
        uint256 _amountVoteTokens
    ) internal {
        require(
            getProposalStatus(_class, _nonce) == ProposalStatus.Active,
            "Gov: vote not active"
        );

        uint256 day = _getVotingDay(_class, _nonce);
        uint256 dayVoteTokens = totalVoteTokenPerDay[_class][_nonce][day];

        totalVoteTokenPerDay[_class][_nonce][day] = dayVoteTokens + _amountVoteTokens;
        _proposalVotes[_class][_nonce].user[_voter].votingDay = day;
        _countVote(_class, _nonce, _voter, _userVote, _amountVoteTokens);
    }

    /**
    * @dev return a proposal structure
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function getProposal(
        uint128 _class,
        uint128 _nonce
    ) public view returns(Proposal memory) {
        return proposal[_class][_nonce];
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
        Proposal memory _proposal = proposal[_class][_nonce];

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
            if (_quorumReached(_class, _nonce) && _voteSucceeded(_class, _nonce)) {
                return ProposalStatus.Succeeded;
            } else {
                return ProposalStatus.Defeated;
            }
        } else {
            if (_vetoApproved(_class, _nonce)) {
                return ProposalStatus.Succeeded;
            } else {
                return ProposalStatus.Defeated;
            }
        }
    }

    //============================
    //REMOVE THIS TESTING FUNCTION
    //============================
    uint256 count;
    function test() public {
        count = count + 1;
    }
    //============================

    /**
    * @dev set a new address for debond operator
    * @param _newDebondOperator new debond operator address
    */
    function setNewDebondOperator(address _newDebondOperator) public returns(bool) {
        debondOperator = _newDebondOperator;

        return true;
    }

    /**
    * @dev set the vote quorum for a given class (it's a percentage)
    * @param _class proposal class
    * @param _quorum the vote quorum
    */
    function setProposalQuorum(
        uint128 _class,
        uint256 _quorum
    ) public onlyDebondOperator {
        proposalClassInfo[_class][1] = _quorum;
    }

    /**
    * @dev get the quorum for a given proposal class
    * @param _class proposal id
    * @param quorum vote quorum
    */
    function getProposalQuorum(
        uint128 _class
    ) public view returns(uint256 quorum) {
        quorum = proposalClassInfo[_class][1];
    }

    /**
    * @dev change the proposal proposal threshold
    * @param _newThreshold new proposal threshold
    */
    function setProposalThreshold(uint256 _newThreshold) public {
        _proposalThreshold = _newThreshold;
    }

    /**
    * @dev return the proposal threshold
    */
    function getProposalThreshold() public view returns(uint256) {
        return _proposalThreshold;
    }

    /**
    * @dev get the user voting date
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param day voting day
    */
    function getVotingDay(
        uint128 _class,
        uint128 _nonce
    ) public view returns(uint256 day) {
        day = _proposalVotes[_class][_nonce].user[_msgSender()].votingDay;
    }

    /**
    * @dev Estimate how much Interest the user has gained since he staked dGoV
    * @param _amount the amount of DGOV staked
    * @param _duration staking duration to estimate interest from
    * @param interest the estimated interest earned so far
    */
    function estimateInterestEarned(
        uint256 _amount,
        uint256 _duration
    ) external view returns(uint256 interest) {
        interest = (_amount * interestRateForStakingDGOV * _duration) / (100 * NUMBER_OF_SECONDS_IN_DAY);
    }

    /**
    * @dev generate a new nonce for a given class
    * @param _class proposal class
    */
    function _generateNewNonce(uint128 _class) internal returns(uint128 nonce) {
        nonce = proposalNonce[_class] + 1;
        proposalNonce[_class] = nonce;
    }

    /**
    * @dev hash a proposal
    * @param _class proposal class
    * @param _targets array of target contracts
    * @param _values array of ether send
    * @param _calldatas array of calldata to be executed
    * @param _descriptionHash the hash of the proposal description
    */
    function _hashProposal(
        uint128 _class,
        uint128 _nonce,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) internal pure returns (uint256 proposalHash) {
        proposalHash = uint256(
            keccak256(
                abi.encode(
                    _class,
                    _nonce,
                    _targets,
                    _values,
                    _calldatas,
                    _descriptionHash
                )
            )
        );
    }

    /**
    * @dev returns the proposal approval mode according to the proposal class
    * @param _class proposal class
    */
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

    /**
    * @dev initialise all contracts
    * @param _governance governance contract address
    * @param _dgovContract dgov contract address
    * @param _dbitContract dbit contract address
    * @param _stakingContract staking contract address
    * @param _voteContract vote contract address
    * @param _settingsContrats governance settings contract address
    * @param _bankContract bank contract address
    * @param _exchangeContract exchange contract address
    */
    function firstSetUp(
        address _governance,
        address _dgovContract,
        address _dbitContract,
        address _stakingContract,
        address _voteContract,
        address _settingsContrats,
        address _bankContract,
        address _exchangeContract
    ) public onlyDebondOperator returns(bool) {
        require(!initialized, "Gov: Already initialized");

        governance = _governance;
        dgovContract = _dgovContract;
        dbitContract = _dbitContract;
        stakingContract = _stakingContract;
        voteTokenContract = _voteContract;
        govSettingsContract = _settingsContrats;
        exchangeContract = _bankContract;
        bankContract = _exchangeContract;

        return true;
    }

    /**
    * @dev return the governance contract address
    */
    function getGovernance() public view override returns(address) {
        return governance;
    }

    function getBenchmarkIR() public view returns(uint256) {
        return benchmarkInterestRate;
    }

    /**
    * @dev get the bnumber of days elapsed since the vote has started
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param day the current voting day
    */
    function _getVotingDay(uint128 _class, uint128 _nonce) internal view returns(uint256 day) {
        Proposal memory _proposal = proposal[_class][_nonce];

        uint256 duration = _proposal.startTime > block.timestamp ?
            0: block.timestamp - _proposal.startTime;
        
        day = (duration / NUMBER_OF_SECONDS_IN_DAY) + 1;
    }

    /**
    * @dev get the number of days elapsed since the user has voted
    * @param _voter the address of the voter
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param numberOfDay the number of days
    */
    function _getNumberOfDaysRewarded(
        address _voter,
        uint128 _class,
        uint128 _nonce
    ) internal view returns(uint256 numberOfDay) {
        uint256 proposalDurationInDay = votingReward[_class].numberOfVotingDays;
        uint256 votingDay = _proposalVotes[_class][_nonce].user[_voter].votingDay;

        numberOfDay = (proposalDurationInDay - votingDay) + 1;
    }

    function getBudget() public view returns(uint256, uint256) {
        return (dbitBudgetPPM, dgovBudgetPPM);
    }

    
    /****************************************************************************
    *                          Executable functions
    ****************************************************************************/
    /**
    * @dev update the governance contract
    * @param _newGovernanceAddress new address for the Governance contract
    * @param _executor address of the executor
    */
    function updateGovernanceContract(
        address _newGovernanceAddress,
        address _executor
    ) public returns(bool) {
        require(
            _executor == debondTeam || _executor == debondOperator,
            "Gov: can't execute this task"
        );

        governance = _newGovernanceAddress;

        return true;
    }

    /**
    * @dev update the exchange contract
    * @param _newExchangeAddress new address for the Exchange contract
    * @param _executor address of the executor
    */
    function updateExchangeContract(
        address _newExchangeAddress,
        address _executor
    ) public returns(bool) {
        require(
            _executor == debondTeam || _executor == debondOperator,
            "Gov: can't execute this task"
        );

        exchangeContract = _newExchangeAddress;

        return true;
    }

    /**
    * @dev update the bank contract
    * @param _newBankAddress new address for the Bank contract
    * @param _executor address of the executor
    */
    function updateBankContract(
        address _newBankAddress,
        address _executor
    ) public returns(bool) {
        require(
            _executor == debondTeam || _executor == debondOperator,
            "Gov: can't execute this task"
        );

        bankContract = _newBankAddress;

        return true;
    }

    /**
    * @dev update the benchmark interest rate
    * @param _newBenchmarkInterestRate new benchmark interest rate
    * @param _executor address of the executor
    */
    function updateBenchmarkInterestRate(
        uint256 _newBenchmarkInterestRate,
        address _executor
    ) public override returns(bool) {
        require(
            _executor == debondTeam || _executor == debondOperator,
            "Gov: can't execute this task"
        );

        benchmarkInterestRate = _newBenchmarkInterestRate;

        return true;
    }

    /**
    * @dev change the community fund size (DBIT, DGOV)
    * @param _proposalClass proposal class
    * @param _newDBITBudgetPPM new DBIT budget for community
    * @param _newDGOVBudgetPPM new DGOV budget for community
    * @param _executor address of the executor
    */
    function changeCommunityFundSize(
        uint128 _proposalClass,
        uint256 _newDBITBudgetPPM,
        uint256 _newDGOVBudgetPPM,
        address _executor
    ) public returns(bool) {
        require(
            _executor == debondTeam || _executor == debondOperator,
            "Gov: can't execute this task"
        );
        require(_proposalClass < 1, "Gov: class not valid");

        dbitBudgetPPM = _newDBITBudgetPPM;
        dgovBudgetPPM = _newDGOVBudgetPPM;

        return true;
    }

    /**
    * @dev change the team allocation - (DBIT, DGOV)
    * @param _to the address that should receive the allocation tokens
    * @param _newDBITPPM the new DBIT allocation
    * @param _newDGOVPPM the new DGOV allocation
    * @param _executor address of the executor
    */
    function changeTeamAllocation(
        address _to,
        uint256 _newDBITPPM,
        uint256 _newDGOVPPM,
        address _executor
    ) public returns(bool) {
        require(
            _executor == debondTeam || _executor == debondOperator,
            "Gov: can't execute this task"
        );

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

    /**
    * @dev mint allocated DBIT to a given address
    * @param _to the address to mint DBIT to
    * @param _amountDBIT the amount of DBIT to mint
    * @param _amountDGOV the amount of DGOV to mint
    * @param _executor address of the executor
    */
    function mintAllocatedToken(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV,
        address _executor
    ) public returns(bool) {
        require(
            _executor == debondTeam || _executor == debondOperator,
            "Gov: can't execute this task"
        );

        AllocatedToken memory _allocatedToken = allocatedToken[_to];

        uint256 _dbitCollaterizedSupply = IDebondToken(dbitContract).collaterisedSupply();
        uint256 _dgovCollaterizedSupply = IDebondToken(dgovContract).collaterisedSupply();

        require(
            IDebondToken(dbitContract).allocatedBalance(_to) + _amountDBIT <=
            _dbitCollaterizedSupply * _allocatedToken.dbitAllocationPPM / 1 ether,
            "Gov: not enough supply"
        );
        require(
            IDebondToken(dgovContract).allocatedBalance(_to) + _amountDGOV <=
            _dgovCollaterizedSupply * _allocatedToken.dgovAllocationPPM / 1 ether,
            "Gov: not enough supply"
        );

        IDebondToken(dbitContract).mintAllocatedSupply(_to, _amountDBIT);
        allocatedToken[_to].allocatedDBITMinted += _amountDBIT;
        dbitTotalAllocationDistributed += _amountDBIT;

        IDebondToken(dgovContract).mintAllocatedSupply(_to, _amountDGOV);
        allocatedToken[_to].allocatedDGOVMinted += _amountDGOV;
        dgovTotalAllocationDistributed += _amountDGOV;

        return true;
    }

    /**
    * @dev claim fund for a proposal
    * @param _proposalClass class of the proposal
    * @param _to address to transfer fund
    * @param _amountDBIT DBIT amount to transfer
    * @param _amountDGOV DGOV amount to transfer
    */
    function claimFundForProposal(
        uint128 _proposalClass,
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) public nonReentrant returns(bool) {
        require(_proposalClass <= 2, "Gov: class not valid");

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

        IDebondToken(dbitContract).mintAllocatedSupply(_to, _amountDBIT);
        allocatedToken[_to].allocatedDBITMinted += _amountDBIT;
        dbitTotalAllocationDistributed += _amountDBIT;

        IDebondToken(dgovContract).mintAllocatedSupply(_to, _amountDGOV);
        allocatedToken[_to].allocatedDGOVMinted += _amountDGOV;
        dgovTotalAllocationDistributed += _amountDGOV;

        return true;
    }
    //**************************************************************************/

}