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

    modifier onlyDBITorDGOV(address _tokenAddress) {
        require(
            _tokenAddress == IGovStorage(govStorageAddress).getDGOVAddress() ||
            _tokenAddress == IGovStorage(govStorageAddress).getDBITAddress(),
            "Gov: wrong token address"
        );
        _;
    }

    modifier onlyGov {
        require(
            msg.sender == IGovStorage(govStorageAddress).getGovernanceAddress(),
            "Executable: Only Gov"
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

    constructor(address _govStorageAddress) {
        govStorageAddress = _govStorageAddress;
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
        address _targets,
        uint256 _values,
        bytes memory _calldatas,
        string memory _title,
        bytes32 _descriptionHash
    ) public {
        uint128 nonce = _generateNewNonce(_class);
      
        (
            uint256 start,
            uint256 end,
            ProposalApproval approval
        ) =
        IProposalLogic(
            IGovStorage(govStorageAddress).getProposalLogicContract()
        ).setProposal(
            _class, nonce, msg.sender, _targets, _values, _calldatas, _title, _descriptionHash
        );

        require(
            IERC20(
                IGovStorage(govStorageAddress).getVoteTokenContract()
            ).balanceOf(msg.sender) - 
            IVoteToken(
                IGovStorage(govStorageAddress).getVoteTokenContract()
            ).totalLockedBalanceOf(msg.sender) >=
            IGovStorage(govStorageAddress).getProposalThreshold(),
            "Gov: insufficient vote tokens"
        );

        IVoteToken(
            IGovStorage(govStorageAddress).getVoteTokenContract()
        ).lockTokens(
            msg.sender,
            msg.sender,
            IGovStorage(govStorageAddress).getProposalThreshold(),
            _class,
            nonce
        );

        emit ProposalCreated(
            _class,
            nonce,
            start,
            end,
            msg.sender,
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
    ) public {
        require(
            IGovStorage(govStorageAddress).getProposalStatus(_class, _nonce) == 
            IGovSharedStorage.ProposalStatus.Succeeded,
            "Gov: only succeded proposals"
        );

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
        address _targets,
        uint256 _values,
        bytes memory _calldatas
    ) private {
        string memory errorMessage = "Executable: execute proposal reverted";

        (
            bool success,
            bytes memory data
        ) = _targets.call{value: _values}(_calldatas);

        Address.verifyCallResult(success, data, errorMessage);
    }

    /**
    * @dev cancel a proposal
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
        require(msg.sender == proposal.proposer, "Gov: permission denied");

        ProposalStatus status = IGovStorage(
            govStorageAddress
        ).getProposalStatus(_class, _nonce);

        require(
            status != ProposalStatus.Canceled &&
            status != ProposalStatus.Executed
        );

        IGovStorage(
            govStorageAddress
        ).setProposalStatus(_class, _nonce, ProposalStatus.Canceled);

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
        address voter = msg.sender;
        require(voter != address(0), "Governance: zero address");
        require(
            IGovStorage(
                govStorageAddress
            ).getProposalStatus(_class, _nonce) == ProposalStatus.Active,
            "Gov: vote not active"
        );
        require(
            _amountVoteTokens <= IERC20(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).allowance(_tokenOwner, voter),
            "ProposalLogic: not enough allowance"
        );
        require(
            _amountVoteTokens <= 
            IERC20(
                IGovStorage(govStorageAddress).getVoteTokenContract()
            ).balanceOf(_tokenOwner) - 
            IVoteToken(
                IGovStorage(govStorageAddress).getVoteTokenContract()
            ).totalLockedBalanceOf(_tokenOwner),
            "ProposalLogic: not enough vote tokens"
        );

        // lock vote tokens
        IVoteToken(
            IGovStorage(govStorageAddress).getVoteTokenContract()
        ).lockTokens(_tokenOwner, voter, _amountVoteTokens, _class, _nonce);     

        // update the vote object
        IProposalLogic(
            IGovStorage(govStorageAddress).getProposalLogicContract()
        ).setVote(_class, _nonce, voter, _userVote, _amountVoteTokens);

        emit voted(_class, _nonce, voter, _stakingCounter, _amountVoteTokens);
    }

    /**
    * @dev veto a proposal
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _veto, true if vetoed, false otherwise
    */
    function veto(
        uint128 _class,
        uint128 _nonce,
        bool _veto
    ) public {
        address vetoAddress = msg.sender;
        require(msg.sender == IGovStorage(govStorageAddress).getVetoOperator(), "Gov: only veto operator");
        require(_class >= 0 && _nonce > 0, "Gov: invalid proposal");
        require(
            IGovStorage(
                govStorageAddress
            ).getProposalStatus(_class, _nonce)  == ProposalStatus.Active,
            "Gov: vote not active"
        );

        IProposalLogic(
            IGovStorage(govStorageAddress).getProposalLogicContract()
        ).setVetoApproval(_class, _nonce, _veto, vetoAddress);

        emit vetoUsed(_class, _nonce);
    }

    /**
    * @dev stake DGOV tokens
    * @param _amount amount of DGOV to stake
    * @param _durationIndex index of the staking duration -defined in the staking contract-
    */
    function stakeDGOV(uint256 _amount, uint256 _durationIndex) public nonReentrant {
        address staker = msg.sender;
        require(staker != address(0), "StakingDGOV: zero address");

        uint256 stakerBalance = IERC20(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).balanceOf(staker);
        require(_amount <= stakerBalance, "Debond: not enough dGov");

        // update the user staking data
        (uint256 duration, uint256 _amountToMint) = IStaking(
            IGovStorage(govStorageAddress).getStakingContract()
        ).stakeDgovToken(staker, _amount, _durationIndex);

        // mint vote tokens into the staker account
        IVoteToken(
            IGovStorage(govStorageAddress).getVoteTokenContract()
        ).mintVoteToken(staker, _amountToMint);
        
        // transfer DGOV to the staking contract
        IERC20(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).transferFrom(staker, IGovStorage(govStorageAddress).getStakingContract(), _amount);

        emit dgovStaked(staker, _amount, duration);
    }

    /**
    * @dev unstake DGOV tokens
    * @param _stakingCounter counter that returns the rank of staking dGoV
    */
    function unstakeDGOV(
        uint256 _stakingCounter
    ) public {
        address staker = msg.sender;
        require(staker != address(0), "Gov: zero address");

        // update the user staking data and stransfer DGOV to the staker
        (uint256 amountDGOV, uint256 amountVote) = IStaking(
            IGovStorage(govStorageAddress).getStakingContract()
        ).transferDgov(staker, _stakingCounter);

        // burn the staker vote tokens
        IVoteToken(
            IGovStorage(govStorageAddress).getVoteTokenContract()
        ).burnVoteToken(staker, amountVote);

        // calculate the interest earned by staking DGOV
        (uint256 interest, uint256 duration) = IStaking(
            IGovStorage(govStorageAddress).getStakingContract()
        ).calculateInterestEarned(
            staker,
            amountDGOV,
            _stakingCounter
        );

        // transfer DBIT interest from APM to the staker account
        IAPM(
            IGovStorage(govStorageAddress).getAPMAddress()
        ).removeLiquidity(
            staker,
            IGovStorage(govStorageAddress).getDBITAddress(),
            interest
        );

        emit dgovUnstaked(staker, duration, interest);
    }

    /**
    * @dev withdraw interest earned -by staking DGOV- before end of staking
    * @param _stakingCounter counter that returns the rank of staking dGoV
    */
    function withdrawInterest(
        uint256 _stakingCounter
    ) public {
        address staker = msg.sender;

        (
            uint256 amount,
            uint256 startTime,
            uint256 duration,
            uint256 lastWithdrawTime
        ) = IStaking(
            IGovStorage(govStorageAddress).getStakingContract()
        ).getStakingData(staker, _stakingCounter);

        require(amount > 0, "Gov: no DGOV staked");
        require(
            block.timestamp >= startTime && block.timestamp <= startTime + duration,
            "Gov: Unstake DGOV to get interests"
        );

        uint256 currentDuration = block.timestamp - lastWithdrawTime;

        // calculate the interest earned since last winthdraw
        uint256 interestEarned = IStaking(
            IGovStorage(govStorageAddress).getStakingContract()
        ).estimateInterestEarned(amount, currentDuration);

        // update the last withdraw time
        IStaking(
            IGovStorage(govStorageAddress).getStakingContract()
        ).updateLastTimeInterestWithdraw(staker, _stakingCounter);

        // transfer DBIT interests from APM to the staker account
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
        address tokenOwner = msg.sender;
        require(tokenOwner != address(0), "Gov: zero address");

        ProposalStatus status = IGovStorage(
            govStorageAddress
        ).getProposalStatus(_class, _nonce);

        address proposer = IGovStorage(
            govStorageAddress
        ).getProposalProposer(_class, _nonce);

        require(
            status == ProposalStatus.Canceled ||
            status == ProposalStatus.Succeeded ||
            status == ProposalStatus.Defeated ||
            status == ProposalStatus.Executed,
            "ProposalLogic: still voting"
        );

        // proposer locks vote tokens by submiting the proposal, and may not have voted
        if(tokenOwner != proposer) {
            require(
                IProposalLogic(
                    IGovStorage(govStorageAddress).getProposalLogicContract()
                ).hasVoted(_class, _nonce, tokenOwner),
                "Gov: you haven't voted"
            );      
        }

        // update user locked and available vote tokens balances
        IVoteToken(
            IGovStorage(govStorageAddress).getVoteTokenContract()
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
    ) private {
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
    function _generateNewNonce(uint128 _class) private returns(uint128 nonce) {
        nonce = IGovStorage(govStorageAddress).getProposalNonce(_class) + 1;
        IGovStorage(govStorageAddress).setProposalNonce(_class, nonce);
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
        address _tokenAddress
    ) external onlyGov onlyDBITorDGOV(_tokenAddress) {
        require(_proposalClass < 1, "Executable: invalid class");

        require(
            IDebondToken(_tokenAddress).setMaxAllocationPercentage(_newPercentage),
            "Gov: Execution failed"
        );

        emit maxAllocationSet(_tokenAddress, _newPercentage);
    }

    function updateMaxAirdropSupply(
        uint128 _proposalClass,
        uint256 _newSupply,
        address _tokenAddress
    ) external onlyGov onlyDBITorDGOV(_tokenAddress) {
        require(_proposalClass < 1, "Executable: invalid class");

        require(
            IDebondToken(_tokenAddress).setMaxAirdropSupply(_newSupply),
            "Gov: Execution failed"
        );

        emit maxAirdropSupplyUpdated(_tokenAddress, _newSupply);
    }

    function mintAllocatedToken(
        uint128 _proposalClass,
        address _token,
        address _to,
        uint256 _amount
    ) external onlyGov {
        require(_proposalClass < 1, "Executable: invalid proposal class");

        require(
            IExecutable(
                IGovStorage(govStorageAddress).getExecutableContract()
            ).mintAllocatedToken(_token, _to, _amount),
            "Gov: execution failed"
        );

        IDebondToken(_token).mintAllocatedSupply(_to, _amount);

        emit allocationTokenMinted(_token, _to, _amount);
    }
}