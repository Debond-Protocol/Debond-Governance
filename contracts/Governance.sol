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

import "@debond-protocol/debond-apm-contracts/interfaces/IAPM.sol";
import "@debond-protocol/debond-token-contracts/interfaces/IDGOV.sol";
import "@debond-protocol/debond-token-contracts/interfaces/IDebondToken.sol";
import "@debond-protocol/debond-exchange-contracts/interfaces/IExchangeStorage.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IStaking.sol";
import "./interfaces/IVoteToken.sol";
import "./interfaces/IExecutable.sol";
import "./interfaces/IGovSettings.sol";
import "./interfaces/IVoteCounting.sol";
import "./interfaces/IProposalLogic.sol";
import "./interfaces/IGovSharedStorage.sol";
import "./utils/GovernanceMigrator.sol";
import "./Pausable.sol";

/**
* @author Samuel Gwlanold Edoumou (Debond Organization)
*/
contract Governance is GovernanceMigrator, ReentrancyGuard, Pausable, IGovSharedStorage {
    using SafeERC20 for IERC20;

    address govStorageAddress;
    address voteCountingAddress;

    modifier onlyDBITorDGOV(address _tokenAddress) {
        require(
            _tokenAddress == IGovStorage(govStorageAddress).getDGOVAddress() ||
            _tokenAddress == IGovStorage(govStorageAddress).getDBITAddress(),
            "Gov: wrong token address"
        );
        _;
    }

    modifier onlyVetoOperator {
        require(
            msg.sender == IGovStorage(govStorageAddress).getVetoOperator(),
            "Gov: Only veto operator"
        );
        _;
    }

    modifier onlyExec {
        require(
            msg.sender == IGovStorage(govStorageAddress).getExecutableContract(),
            "Gov: Only veto operator"
        );
        _;
    }

    modifier onlySucceededProposals(uint128 _class, uint128 _nonce) {
        require(
            IGovStorage(govStorageAddress).getProposalStatus(_class, _nonce) ==
            IGovSharedStorage.ProposalStatus.Succeeded,
            "Gov: only succeded proposals"
        );
        _;
    }

    constructor(
        address _govStorageAddress,
        address _voteCountingAddress
    ) {
        govStorageAddress = _govStorageAddress;
        voteCountingAddress = _voteCountingAddress;
    }

    /**
    * @dev store a new proposal onchain
    * @param _class proposal class
    * @param _targets array of contract to interact with if the proposal passes
    * @param _values array contraining ethers to send (can be array of zeros)
    * @param _calldatas array of encoded functions to call if the proposal passes
    * @param _title proposal title
    * @param _descriptionHash proposal description Hash
    */
    function createProposal(
        uint128 _class,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _title,
        bytes32 _descriptionHash
    ) public {
        uint128 _nonce = generateNewNonce(_class);
        (
            uint256 start, uint256 end, ProposalApproval approval
        ) =
        IProposalLogic(
            IGovStorage(govStorageAddress).getProposalLogicContract()
        ).proposalSetUp(
            _class, _nonce, _msgSender(), _targets, _values, _calldatas, _title, _descriptionHash
        );

        emit ProposalCreated(
            _class,
            _nonce,
            start,
            end,
            _msgSender(),
            _targets,
            _values,
            _calldatas,
            _title,
            _descriptionHash,
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
    ) external onlySucceededProposals(_class, _nonce){

        Proposal memory proposal = IGovStorage(
            govStorageAddress
        ).getProposalStruct(_class, _nonce);

        IGovStorage(
            govStorageAddress
        ).setProposalStatus(_class, _nonce, ProposalStatus.Executed);

        _execute(proposal.targets, proposal.values, proposal.calldatas);

        emit ProposalExecuted(_class, _nonce);
    }

    function _execute(
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas
    ) private {
        string memory errorMessage = "Executable: execute proposal reverted";
        
        for (uint256 i = 0; i < _targets.length; i++) {
            (
                bool success,
                bytes memory data
            ) = _targets[i].call{value: _values[i]}(_calldatas[i]);

            Address.verifyCallResult(success, data, errorMessage);
        }
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
        Proposal memory proposal = IGovStorage(
            govStorageAddress
        ).getProposalStruct(_class, _nonce);

        require(_msgSender() == proposal.proposer, "Gov: permission denied");

        IProposalLogic(
            IGovStorage(govStorageAddress).getProposalLogicContract()
        ).cancelProposal(_class, _nonce);

        emit ProposalCanceled(_class, _nonce);
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

        // TODO don't we need to chack if a proposal exists first for a class and nonce given?
        IProposalLogic(
            IGovStorage(govStorageAddress).getProposalLogicContract()
        ).voteRequirement(_class, _nonce, _tokenOwner, voter, _amountVoteTokens, _stakingCounter);

        IProposalLogic(
            IGovStorage(govStorageAddress).getProposalLogicContract()
        ).vote(_class, _nonce, voter, _userVote, _amountVoteTokens);

        emit voted(_class, _nonce, voter, _stakingCounter, _amountVoteTokens);
    }

    /**
    * @dev veto the proposal
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _veto, true if vetoed, false otherwise
    */
    function veto(
        uint128 _class,
        uint128 _nonce,
        bool _veto
    ) public onlyVetoOperator {
        address vetoAddress = _msgSender();
        require(_class >= 0 && _nonce > 0, "Gov: invalid proposal");
        require(
            IGovStorage(
                govStorageAddress
            ).getProposalStatus(_class, _nonce)  == ProposalStatus.Active,
            "Gov: vote not active"
        );

        IVoteCounting(
            voteCountingAddress
        ).setVetoApproval(_class, _nonce, _veto, vetoAddress);

        emit vetoUsed(_class, _nonce);
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
    ) public nonReentrant returns(bool staked) {
        address staker = _msgSender();

        IStaking(
            IGovStorage(govStorageAddress).getStakingContract()
        ).stakeDgovToken(staker, _amount, _duration);

        staked = true;

        emit dgovStaked(staker, _amount, _duration);
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
        require(staker != address(0), "Gov: zero address");

        (uint256 amountStaked, uint256 interest, uint256 duration) = IProposalLogic(
            IGovStorage(govStorageAddress).getProposalLogicContract()
        ).unstakeDGOVandCalculateInterest(staker, _stakingCounter);

        IAPM(
            IGovStorage(govStorageAddress).getAPMAddress()
        ).removeLiquidity(
            staker,
            IGovStorage(govStorageAddress).getDBITAddress(),
            amountStaked * interest / 1 ether
        );

        unstaked = true;

        emit dgovUnstaked(staker, duration, interest);
    }

    /**
    * @dev withdraw interest earned by staking DGOV
    * @param _stakingCounter counter that returns the rank of staking dGoV
    */
    function withdrawInterest(
        uint256 _stakingCounter
    ) public {
        address staker = _msgSender();
        uint256 StackedDGOV = IStaking(
            IGovStorage(govStorageAddress).getStakingContract()
        ).getStakedDGOVAmount(staker, _stakingCounter);

        require(StackedDGOV > 0, "Gov: no DGOV staked");

        (uint256 startTime, uint256 duration, uint256 lastWithdrawTime) = IStaking(
            IGovStorage(govStorageAddress).getStakingContract()
        ).getStartTimeDurationAndLastWithdrawTime(staker, _stakingCounter);

        require(
            block.timestamp >= startTime && block.timestamp <= startTime + duration,
            "Gov: Unstake DGOV to get interests"
        );

        uint256 currentDuration = block.timestamp - lastWithdrawTime;

        uint256 interestEarned = IGovStorage(
            govStorageAddress
        ).estimateInterestEarned(StackedDGOV, currentDuration);

        IStaking(
            IGovStorage(govStorageAddress).getStakingContract()
        ).setLastTimeInterestWithdraw(staker, _stakingCounter);

        IAPM(
            IGovStorage(govStorageAddress).getAPMAddress()
        ).removeLiquidity(
            staker,
            IGovStorage(govStorageAddress).getDBITAddress(),
            interestEarned
        );

        emit interestWithdrawn(_stakingCounter, interestEarned);
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

        IProposalLogic(
            IGovStorage(govStorageAddress).getProposalLogicContract()
        ).unlockVoteTokens(_class, _nonce, tokenOwner);

        _transferDBITInterest(_class, _nonce, tokenOwner);

        emit voteTokenUnlocked(_class, _nonce, tokenOwner);
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
        uint256 reward = IProposalLogic(
            IGovStorage(govStorageAddress).getProposalLogicContract()
        ).calculateReward(_class, _nonce, _tokenOwner);


        IAPM(
            IGovStorage(govStorageAddress).getAPMAddress()
        ).removeLiquidity(
            _tokenOwner,
            IGovStorage(govStorageAddress).getDBITAddress(),
            reward
        );
    }

    /**
    * @dev generate a new nonce for a given class
    * @param _class proposal class
    * @param nonce newly generated nonce for the given class
    */
    function generateNewNonce(uint128 _class) private view returns(uint128 nonce) {
        nonce = IGovStorage(govStorageAddress).getProposalNonce(_class) + 1;
    }

    /**
    * @dev transfer tokens from Governance contract to an address
    * @param _token token address
    * @param _to recipient address
    * @param _amount amount of tokens to transfer
    */
    function migrate(
        address _token,
        address _to,
        uint256 _amount
    ) external override onlyExec {
        IERC20(_token).safeTransfer(_to, _amount);
    }
}
