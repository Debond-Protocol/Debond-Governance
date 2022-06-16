pragma solidity ^0.8.0;

// SPDX-License-Identifier: apache 2.0
/*
    Copyright 2020 Sigmoid Foundation <info@dGOV.finance>
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
import "./NewGovStorage.sol";
import "./utils/VoteCounting.sol";
import "./interfaces/IVoteToken.sol";
import "./interfaces/IGovSettings.sol";
import "./interfaces/INewStaking.sol";
import "./interfaces/IGovernance.sol";
import "./interfaces/INewGovernance.sol";
import "./test/DBIT.sol";
import "./Pausable.sol";

/**
* @author Samuel Gwlanold Edoumou (Debond Organization)
*/
contract NewGovernance is NewGovStorage, VoteCounting, ReentrancyGuard, Pausable {
    constructor(
        address _dgovContract,
        address _dbitContract,
        address _stakingContract,
        address _voteTokenContract,
        address _govSettingsContract
    ) {
        dgovContract = _dgovContract;
        dbitContract = _dbitContract;
        stakingContract = _stakingContract;
        voteTokenContract = _voteTokenContract;
        govSettingsContract = _govSettingsContract;

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

        votingReward[2].numberOfVotingDays = 3;
        votingReward[2].numberOfDBITDistributedPerDay = 5;

    }

    /**
    * @dev see {INewGovernance} for description
    * @param _class proposal class
    */
    function createProposal(
        uint128 _class,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _description
    ) public returns(uint128 nonce, uint256 proposalId) {
        require(
            _targets.length == _values.length &&
            _values.length == _calldatas.length,
            "Gov: invalid proposal"
        );

        nonce = _generateNewNonce(_class);
        ProposalApproval approval = _approvalMode(_class);

        proposalId = _hashProposal(
            _class,
            nonce,
            _targets,
            _values,
            _calldatas,
            keccak256(bytes(_description))
        );

        // ToDo: Discuss with Yu Liu wether to use block.number instead of block.timestamp
        uint256 _start = block.timestamp + IGovSettings(govSettingsContract).votingDelay();
        uint256 _end = _start + IGovSettings(govSettingsContract).votingPeriod();

        proposal[_class][nonce].id = proposalId;
        proposal[_class][nonce].startTime = _start;
        proposal[_class][nonce].endTime = _end;
        proposal[_class][nonce].approvalMode = approval;

        proposalClass[proposalId] = _class;

        emit ProposalCreated(
            _class,
            nonce,
            proposalId,
            _start,
            _end,
            msg.sender,
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
        uint128 _nonce,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        bytes32 _descriptionHash
    ) public returns(uint256 proposalId) {
        proposalId = _hashProposal(
            _class,
            _nonce,
            _targets,
            _values,
            _calldatas,
            _descriptionHash
        );

        ProposalStatus status = getProposalStatus(
            _class,
            _nonce,
            proposalId
        );

        require(
            status == ProposalStatus.Succeeded,
            "Gov: proposal not successful"
        );

        proposal[_class][_nonce].status = ProposalStatus.Executed;

        emit ProposalExecuted(proposalId);

        _execute(_targets, _values, _calldatas);
    }
    
    /**
    * @dev internal execution mechanism
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
    * @param _proposalId proposal Id
    * @param _tokenOwner owner of staked dgov (can delagate their vote)
    * @param _userVote vote type: 0-FOR, 1-AGAINST, 2-ABSTAIN
    * @param _amountVoteTokens amount of vote tokens
    */
    function vote(
        uint256 _proposalId,
        address _tokenOwner,
        uint8 _userVote,
        uint256 _amountVoteTokens,
        uint256 _stakingCounter
    ) public {
        address voter = _msgSender();
        uint128 class = proposalClass[_proposalId];
        uint128 nonce = proposalNonce[class];

        uint256 _dgovStaked = INewStaking(stakingContract).getStakedDGOV(_tokenOwner, _stakingCounter);
        uint256 approvedToSpend = IERC20(dgovContract).allowance(_tokenOwner, voter);

        require(
            _amountVoteTokens <= _dgovStaked &&
            _amountVoteTokens <= approvedToSpend,
            "Gov: not approved or not enough dGoV staked"
        );
        require(
            _amountVoteTokens <= 
            IERC20(voteTokenContract).balanceOf(_tokenOwner) - 
            IVoteToken(voteTokenContract).lockedBalanceOf(_tokenOwner, _proposalId),
            "Gov: not enough vote tokens"
        );

        IVoteToken(voteTokenContract).lockTokens(_tokenOwner, voter, _amountVoteTokens, _proposalId);

        _vote(class, nonce, voter, _userVote, _amountVoteTokens);
    }

    function stakeDGOV(
        uint256 _amount,
        uint256 _duration
    ) public returns(bool staked) {
        address staker = _msgSender();

        INewStaking(stakingContract).stakeDgovToken(staker, _amount, _duration);

        staked = true;
    }

    /**
    * @dev redeem vote tokens and get DBIT rewards
    * @param _proposalId proposal Id
    */
    function unlockVoteTokens(
        uint256 _proposalId
    ) external {
        address tokenOwner = _msgSender();

        uint128 class = proposalClass[_proposalId];
        uint128 nonce = proposalNonce[class];

        require(
            block.timestamp > proposal[class][nonce].endTime,
            "Gov: still voting"
        );
        require(
            hasVoted(_proposalId, tokenOwner),
            "Gov: you haven't voted"
        );
        
        uint256 _amount = IVoteToken(voteTokenContract).lockedBalanceOf(tokenOwner, _proposalId);
        _unlockVoteTokens(_proposalId, tokenOwner, _amount);

        // transfer the rewards earned for this vote
        _transferDBITInterest(_proposalId, tokenOwner);
    }

    /**
    * @dev transfer DBIT interest earned by voting for a proposal
    * @param _proposalId proposal id
    * @param _tokenOwner owner of stacked dgov
    */
    function _transferDBITInterest(
        uint256 _proposalId,
        address _tokenOwner
    ) internal {
        uint128 class = proposalClass[_proposalId];

        ProposalVote storage proposalVote = _proposalVotes[_proposalId];

        require(
            proposalVote.user[_tokenOwner].hasBeenRewarded = false,
            "Gov: already rewarded"
        );
        proposalVote.user[_tokenOwner].hasBeenRewarded = true;

        uint256 _reward;

        for(uint256 i = 1; i <= votingReward[class].numberOfVotingDays; i++) {
            _reward += 1 ether / totalVoteTokenPerDay[_proposalId][i];
        }

        _reward = _reward * proposalVote.user[_tokenOwner].weight * votingReward[class].numberOfDBITDistributedPerDay;
        IERC20(dbitContract).transferFrom(dbitContract, _tokenOwner, _reward);
    }

    /**
    * @dev internal unlockVoteTokens function
    * @param _proposalId proposal Id
    * @param _amount amount of vote tokes to unlock
    * @param _tokenOwner owner of the vote tokens
    */
    function _unlockVoteTokens(uint256 _proposalId, address _tokenOwner, uint256 _amount) internal {
        IVoteToken(voteTokenContract).unlockTokens(_tokenOwner, _amount, _proposalId);
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
        Proposal memory _proposal = proposal[_class][_nonce];
        require(
            getProposalStatus(_class, _nonce, _proposal.id) == ProposalStatus.Active,
            "Gov: vote not active"
        );

        uint256 day = _getVotingDay(_class, _nonce);
        uint256 dayVoteTokens = totalVoteTokenPerDay[_proposal.id][day];

        totalVoteTokenPerDay[_proposal.id][day] = dayVoteTokens + _amountVoteTokens;
        _proposalVotes[_proposal.id].user[_voter].votingDay = day;
        _countVote(_proposal.id, _voter, _userVote, _amountVoteTokens);
    }

    /**
    * @dev return the proposal status
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _id proposal id
    */
    function getProposalStatus(
        uint128 _class,
        uint128 _nonce,
        uint256 _id
    ) public view returns(ProposalStatus unassigned) {
        Proposal memory _proposal = proposal[_class][_nonce];
        require(_proposal.id == _id, "Gov: invalid proposal");

        if (_proposal.status == ProposalStatus.Canceled) {
            return ProposalStatus.Canceled;
        }

        if (_proposal.status == ProposalStatus.Executed) {
            return ProposalStatus.Executed;
        }

        if (_proposal.startTime >= block.timestamp) {
            return ProposalStatus.Pending;
        }

        if (_proposal.endTime >= block.timestamp) {
            return ProposalStatus.Active;
        }

        if (_quorumReached(_proposal.id) && _voteSucceeded(_proposal.id)) {
            return ProposalStatus.Succeeded;
        } else {
            return ProposalStatus.Defeated;
        }
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
    * @dev get the user voting date
    * @param _proposalId proposal Id
    * @param day voting day
    */
    function getVotingDay(uint256 _proposalId) public view returns(uint256 day) {
        day = _proposalVotes[_proposalId].user[_msgSender()].votingDay;
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
    function _approvalMode(
        uint128 _class
    ) internal pure returns(ProposalApproval unsassigned) {
        if (_class == 0 || _class == 1) {
            return ProposalApproval.Approve;
        }

        if (_class == 2) {
            return ProposalApproval.NoVote;
        }
    }

    /**
    * @dev return the governance contract address
    */
    function getGovernance() public view returns(address) {
        return governance;
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
        
        day = (duration / NUMBER_OF_SECONDS_IN_DAY);
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
        Proposal memory _proposal = proposal[_class][_nonce];

        uint256 proposalDurationInDay = votingReward[_class].numberOfVotingDays;
        uint256 votingDay = _proposalVotes[_proposal.id].user[_voter].votingDay;

        numberOfDay = (proposalDurationInDay - votingDay) + 1;
    }

}