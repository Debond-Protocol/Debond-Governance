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

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@debond-protocol/debond-token-contracts/interfaces/IDGOV.sol";
import "@debond-protocol/debond-token-contracts/interfaces/IDebondToken.sol";
import "@debond-protocol/debond-exchange-contracts/interfaces/IExchangeStorage.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IVoteToken.sol";
import "./interfaces/IVoteCounting.sol";
import "./interfaces/IGovSettings.sol";
import "./interfaces/IGovStorage.sol";
import "./interfaces/IGovSharedStorage.sol";
import "./interfaces/IStaking.sol";
import "./interfaces/IExecutable.sol";
import "./interfaces/IProposalLogic.sol";
import "./Pausable.sol";

/**
* @author Samuel Gwlanold Edoumou (Debond Organization)
*/
contract Governance is ReentrancyGuard, Pausable, IGovSharedStorage {
    using SafeERC20 for IERC20;

    address govStorageAddress;
    address voteCountingAddress;

    modifier onlyDebondExecutor(address _executor) {
        require(
            _executor == IGovStorage(govStorageAddress).getDebondTeamAddress() ||
            _executor == IGovStorage(govStorageAddress).getVetoOperator(),
            "Gov: can't execute this task"
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

    modifier onlyVetoOperator {
        require(
            msg.sender == IGovStorage(govStorageAddress).getVetoOperator(),
            "Gov: Only veto operator"
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
        (
            uint128 nonce,
            uint256 start,
            uint256 end,
            ProposalApproval approval
        ) = 
        IProposalLogic(
            IGovStorage(govStorageAddress).getProposalLogicContract()
        ).setProposalData(
            _class, _msgSender(), _targets, _values, _calldatas, _title
        );

        IGovStorage(
            govStorageAddress
        ).setProposalDescriptionHash(_class, nonce, _descriptionHash);

        emit ProposalCreated(
            _class,
            nonce,
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
    ) public {
        require(_class >= 0 && _nonce > 0, "Gov: invalid proposal");

        Proposal memory proposal = IGovStorage(
            govStorageAddress
        ).getProposalStruct(_class, _nonce);
        
        require(
            msg.sender == proposal.proposer,
            "Gov: permission denied"
        );
      
        IProposalLogic(
            IGovStorage(govStorageAddress).getProposalLogicContract()
        ).checkAndSetProposalStatus(_class, _nonce);

        emit ProposalExecuted(_class, _nonce);

        _execute(proposal.targets, proposal.values, proposal.calldatas);
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

        IProposalLogic(
            IGovStorage(govStorageAddress).getProposalLogicContract()
        ).voteRequirement(_class, _nonce, _tokenOwner, voter, _amountVoteTokens, _stakingCounter);

        IProposalLogic(
            IGovStorage(govStorageAddress).getProposalLogicContract()
        ).vote(_class, _nonce, voter, _userVote, _amountVoteTokens);
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
    ) public onlyVetoOperator {
        address vetoAddress = _msgSender();
        require(_class >= 0 && _nonce > 0, "Gov: invalid proposal");
        require(
            IGovStorage(
                govStorageAddress
            ).getProposalStatus(_class, _nonce)  == ProposalStatus.Active,
            "Gov: vote not active"
        );

        if (_approval == true) {
            IVoteCounting(voteCountingAddress).setVetoApproval(_class, _nonce, 1, vetoAddress);
        } else {
            IVoteCounting(voteCountingAddress).setVetoApproval(_class, _nonce, 2, vetoAddress);
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
    ) public nonReentrant returns(bool staked) {
        address staker = _msgSender();

        IStaking(
            IGovStorage(govStorageAddress).getStakingContract()
        ).stakeDgovToken(staker, _amount, _duration);

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
        require(staker != address(0), "Gov: zero address");

        (uint256 amountStaked, uint256 interest) = IProposalLogic(
            IGovStorage(govStorageAddress).getProposalLogicContract()
        ).unstakeDGOVandCalculateInterest(staker, _stakingCounter);

        // MUST BE TRANSFERRED FROM APM
        IERC20(
            IGovStorage(govStorageAddress).getDBITAddress()
        ).transfer(staker, amountStaked * interest / 1 ether);

        unstaked = true;
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

        // MUST BE TRANSFERRED FROM APM
        IERC20(
            IGovStorage(govStorageAddress).getDBITAddress()
        ).transfer(staker, interestEarned);
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

        // MUST BE TRANSFERRED FROM APM
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
        uint256 reward = IProposalLogic(
            IGovStorage(govStorageAddress).getProposalLogicContract()
        ).calculateReward(_class, _nonce, _tokenOwner);

        // MUST BE TRANSFERRED FROM APM
        IERC20(
            IGovStorage(govStorageAddress).getDBITAddress()
        ).transfer(_tokenOwner, reward);
    }

    /**
    * @dev set the vote quorum for a given class (it's a percentage)
    * @param _class proposal class
    * @param _quorum the vote quorum
    */
    function setProposalQuorum(
        uint128 _class,
        uint256 _quorum
    ) public onlyVetoOperator {
        IGovStorage(govStorageAddress).setProposalClassInfo(_class, 1, _quorum);
    }

    /**
    * @dev get the quorum for a given proposal class
    * @param _class proposal id
    * @param quorum vote quorum
    */
    function getProposalQuorum(
        uint128 _class
    ) public view returns(uint256 quorum) {
        quorum = IGovStorage(govStorageAddress).getProposalClassInfo(_class, 1);
    }

    /**
    * @dev change the proposal proposal threshold
    * @param _newThreshold new proposal threshold
    */
    function setProposalThreshold(
        uint256 _newThreshold,
        address _executor
    ) public onlyVetoOperator {
        IGovStorage(govStorageAddress).setThreshold(_newThreshold, _executor);
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
    
    /**********************************************************************************
    * External Executable functions (used to change params in contracts like Bank, etc)
    **********************************************************************************/  
    function setMaxSupply(
        uint256 maxSupply
    ) public onlyVetoOperator returns (bool) {
        IDGOV(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).setMaxSupply(maxSupply);

        return true;
    }

    /**
    * @dev set the max supply of Debond token
    * @param newSupply new supply of the Debond token
    * @param _tokenAddress address of the Debond token (either DGOV or DBIT)
    */
    function setMaxAirdropSupply(
        uint256 newSupply,
        address _tokenAddress
    ) public onlyVetoOperator onlyDBITorDGOV(_tokenAddress) returns (bool) {
        require(_tokenAddress != address(0), "Gov: zero address");

        IDebondToken(_tokenAddress).setMaxAirdropSupply(newSupply);

        return true;
    }

    /**
    * @dev set the maximum allocation percentage
    * @dev new maximum allocation percentage
    * @param _tokenAddress address of the Debond token (either DGOV or DBIT)
    */
    function setMaxAllocationPercentage(
        uint256 newPercentage,
        address _tokenAddress
    ) public onlyVetoOperator onlyDBITorDGOV(_tokenAddress) returns (bool) {
        require(_tokenAddress != address(0), "Gov: zero address");

        IDebondToken(_tokenAddress).setMaxAllocationPercentage(newPercentage);

        return true;
    }

    /**
    * @dev set the bank address to Debond Token contract
    * @dev new maximum allocation percentage
    * @param _bankAddress new bank address
    * @param _tokenAddress address of the Debond token (either DGOV or DBIT)
    */
    function setBankAddressInDebondToken(
        address _bankAddress,
        address _tokenAddress
    ) public onlyVetoOperator onlyDBITorDGOV(_tokenAddress) returns(bool) {
        require(
            _bankAddress != address(0) && _tokenAddress != address(0),
            "Gov: zero address"
        );

        IDebondToken(_tokenAddress).setBankAddress(_bankAddress);

        return true;
    }

    /**
    * @dev set the airdrop address to Debond Token contract
    * @dev new maximum allocation percentage
    * @param _airdropAddress new airdrop address
    * @param _tokenAddress address of the Debond token (either DGOV or DBIT)
    */
    function setAirdropAddressInDebondToken(
        address _airdropAddress,
        address _tokenAddress
    ) public onlyVetoOperator onlyDBITorDGOV(_tokenAddress) returns(bool) {
        require(
            _airdropAddress != address(0) && _tokenAddress != address(0),
            "Gov: zero address"
        );

        IDebondToken(_tokenAddress).setAirdropAddress(_airdropAddress);

        return true;
    }

    /**
    * @dev set the exchange address to Debond Token contract
    * @dev new maximum allocation percentage
    * @param _exchangeAddress new exchange address
    * @param _tokenAddress address of the Debond token (either DGOV or DBIT)
    */
    function setExchangeAddressInDebondToken(
        address _exchangeAddress,
        address _tokenAddress
    ) public onlyVetoOperator onlyDBITorDGOV(_tokenAddress) returns(bool) {
        require(
            _exchangeAddress != address(0) && _tokenAddress != address(0),
            "Gov: zero address"
        );

        IDebondToken(_tokenAddress).setExchangeAddress(_exchangeAddress);

        return true;
    }

    /**
    * @dev set the exchange address in exchange storage
    * @param _exchangeAddress exchange new address
    */
    function setExchangeNewAddress(
        address _exchangeAddress
    ) public onlyVetoOperator returns(bool) {
        require(_exchangeAddress != address(0), "Gov: zero address");

        IExchangeStorage(
            IGovStorage(govStorageAddress).getExchangeStorageAddress()
        ).setExchangeAddress(_exchangeAddress);

        return true;
    }

    /**
    * @dev set the maximum auction duration in exchange
    * @param _maxAuctionDuration new maximum auction duration
    */
    function setMaxAuctionDuration(
        uint256 _maxAuctionDuration
    ) public onlyVetoOperator returns(bool) {
        IExchangeStorage(
            IGovStorage(govStorageAddress).getExchangeStorageAddress()
        ).setMaxAuctionDuration(_maxAuctionDuration);

        return true;
    }

    /**
    * @dev set the minimum auction duration in exchange
    * @param _minAuctionDuration new minimum auction duration
    */
    function setMinAuctionDuration(
        uint256 _minAuctionDuration
    ) public onlyVetoOperator returns(bool) {
        IExchangeStorage(
            IGovStorage(govStorageAddress).getExchangeStorageAddress()
        ).setMinAuctionDuration(_minAuctionDuration);

        return true;
    }

    /**
    * @dev Migrate ERC20 tokens from an address to another address
    * @param _token address of the token
    * @param _from token owner
    * @param _to recipient address
    * @param _amount the amount of tokens to trensfer
    */
    function MigrateTokens(
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) external {
        SafeERC20.safeTransferFrom(IERC20(_token), _from, _to, _amount);
    }
}