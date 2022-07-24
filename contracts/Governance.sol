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
import "./interfaces/IVoteToken.sol";
import "./interfaces/IVoteCounting.sol";
import "./interfaces/IGovSettings.sol";
import "./interfaces/IGovStorage.sol";
import "./interfaces/IGovSharedStorage.sol";
import "./interfaces/IStaking.sol";
import "./interfaces/IExecutable.sol";
import "./Pausable.sol";

/**
* @author Samuel Gwlanold Edoumou (Debond Organization)
*/
contract Governance is ReentrancyGuard, Pausable, IGovSharedStorage {
    address govStorageAddress;
    address voteCountingAddress;

    modifier onlyDebondOperator {
        require(msg.sender == IGovStorage(govStorageAddress).getDebondOperator(),
        "Gov: Need rights");
        _;
    }

    modifier onlyDebondExecutor(address _executor) {
        require(
            _executor == IGovStorage(govStorageAddress).getDebondTeamAddress() ||
            _executor == IGovStorage(govStorageAddress).getDebondOperator(),
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

    /**
    * @dev governance constructor
    */
    constructor(
        address _govStorageAddress,
        address _voteCountingAddress
    ) {
        govStorageAddress = _govStorageAddress;
        voteCountingAddress = _voteCountingAddress;
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
    ) public returns(uint128 nonce) {
        require(
            IVoteToken(
                IGovStorage(govStorageAddress).getVoteTokenContract()
            ).availableBalance(_msgSender()) >=
            IGovStorage(govStorageAddress).getThreshold(),
            "Gov: insufficient vote tokens"
        );

        require(
            _targets.length == _values.length &&
            _values.length == _calldatas.length,
            "Gov: invalid proposal"
        );

        nonce = _generateNewNonce(_class);
        ProposalApproval approval = getApprovalMode(_class);

        uint256 _start = block.timestamp + IGovSettings(
            IGovStorage(govStorageAddress).getGovSettingContract()
        ).votingDelay();
        
        uint256 _end = _start + IGovSettings(
            IGovStorage(govStorageAddress).getGovSettingContract()
        ).votingPeriod();

        IGovStorage(govStorageAddress).setProposal(
            _class,
            nonce,
            _start,
            _end,
            _msgSender(),
            approval,
            _targets,
            _values,
            _calldatas,
            _description
        );

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
    function cancelProposal(
        uint128 _class,
        uint128 _nonce
    ) public {
        ProposalStatus status = getProposalStatus(
            _class,
            _nonce
        );

        Proposal memory _proposal = IGovStorage(
            govStorageAddress
        ).getProposalStruct(_class, _nonce);

        require(
            status != ProposalStatus.Canceled &&
            status != ProposalStatus.Executed
        );
        
        require(
            msg.sender == _proposal.proposer,
            "Gov: permission denied"
        );

        IGovStorage(
            govStorageAddress
        ).setProposalStatus(_class, _nonce, ProposalStatus.Canceled);
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
        require(voter != address(0), "Governance: zero address");
        require(_class >= 0 && _nonce > 0, "Gov: invalid proposal");

        uint256 _dgovStaked = IStaking(
            IGovStorage(govStorageAddress).getStakingContract()
        ).getStakedDGOV(_tokenOwner, _stakingCounter);
        
        uint256 approvedToSpend = IERC20(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).allowance(_tokenOwner, voter);
        
        require(
            _amountVoteTokens <= _dgovStaked &&
            _amountVoteTokens <= approvedToSpend,
            "Gov: not approved or not enough dGoV staked"
        );
    
        require(
            _amountVoteTokens <= 
            IERC20(
                IGovStorage(govStorageAddress).getVoteTokenContract()
            ).balanceOf(_tokenOwner) - 
            IVoteToken(
                IGovStorage(govStorageAddress).getVoteTokenContract()
            ).lockedBalanceOf(_tokenOwner, _class, _nonce),
            "Gov: not enough vote tokens"
        );

        IVoteToken(
            IGovStorage(govStorageAddress).getVoteTokenContract()
        ).lockTokens(_tokenOwner, voter, _amountVoteTokens, _class, _nonce);

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
    ) public onlyVetoOperator {
        address vetoAddress = _msgSender();
        require(_class >= 0 && _nonce > 0, "Gov: invalid proposal");
        require(
            getProposalStatus(_class, _nonce) == ProposalStatus.Active,
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

        uint256 amountStaked = IStaking(
            IGovStorage(govStorageAddress).getStakingContract()
        ).unstakeDgovToken(staker, _stakingCounter);

        // the interest calculated from this function is in ether unit
        uint256 interest = IStaking(
            IGovStorage(govStorageAddress).getStakingContract()
        ).calculateInterestEarned(
            staker,
            _stakingCounter,
            IGovStorage(govStorageAddress).getInterestForStakingDGOV()
        );

        // CHECK WITH YU THE ORIGIN OF DBIT TO TRANSFER
        // ToDo: CHAGE THIS
        // transfer DBIT interests to the staker - the interest is in ether unit
        //IERC20(dbitContract).transferFrom(dbitContract, staker, amountStaked * interest / 1 ether);
        IERC20(
            IGovStorage(govStorageAddress).getDBITAddress()
        ).transfer(staker, amountStaked * interest / 1 ether);

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

        Proposal memory _proposal = IGovStorage(
            govStorageAddress
        ).getProposalStruct(_class, _nonce);

        require(
            block.timestamp > _proposal.endTime,
            "Gov: still voting"
        );
        require(
            IVoteCounting(voteCountingAddress).hasVoted(_class, _nonce, tokenOwner),
            "Gov: you haven't voted"
        );
        
        uint256 _amount = IVoteToken(
            IGovStorage(govStorageAddress).getVoteTokenContract()
        ).lockedBalanceOf(tokenOwner, _class, _nonce);

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
        require(
            !IVoteCounting(voteCountingAddress).hasBeenRewarded(_class, _nonce, _tokenOwner),
            "Gov: already rewarded"
        );
        IVoteCounting(voteCountingAddress).setUserHasBeenRewarded(_class, _nonce, _tokenOwner);

        uint256 _reward;
        
        for(uint256 i = 1; i <= IGovStorage(govStorageAddress).getNumberOfVotingDays(_class); i++) {
            _reward += (1 ether * 1 ether) / IGovStorage(govStorageAddress).getTotalVoteTokenPerDay(_class, _nonce, i);
        }

        _reward = _reward * IVoteCounting(voteCountingAddress).getVoteWeight(_class, _nonce, _tokenOwner) * 
                  IGovStorage(govStorageAddress).getNumberOfDBITDistributedPerDay(_class) / 1 ether;

        IERC20(
            IGovStorage(govStorageAddress).getDBITAddress()
        ).transfer(_tokenOwner, _reward);
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
        IVoteToken(
            IGovStorage(govStorageAddress).getVoteTokenContract()
        ).unlockTokens(_tokenOwner, _amount, _class, _nonce);
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
        IGovStorage(govStorageAddress).increaseTotalVoteTokenPerDay(
            _class, _nonce, day, _amountVoteTokens
        );
        
        IVoteCounting(voteCountingAddress).setVotingDay(
            _class, _nonce, _voter, day
        );

        IVoteCounting(voteCountingAddress).countVote(
            _class, _nonce, _voter, _userVote, _amountVoteTokens
        );
    }

    /**
    * @dev return a proposal structure
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function getProposalStruct(
        uint128 _class,
        uint128 _nonce
    ) public view returns(Proposal memory) {
        return IGovStorage(govStorageAddress).getProposalStruct(_class, _nonce);
    }

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
        return IGovStorage(govStorageAddress).getProposal(_class, _nonce);
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
        Proposal memory _proposal = IGovStorage(govStorageAddress).getProposalStruct(_class, _nonce);
        
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
                IVoteCounting(voteCountingAddress).quorumReached(_class, _nonce) && 
                IVoteCounting(voteCountingAddress).voteSucceeded(_class, _nonce)
            ) {
                return ProposalStatus.Succeeded;
            } else {
                return ProposalStatus.Defeated;
            }
        } else {
            if (IVoteCounting(voteCountingAddress).vetoApproved(_class, _nonce)) {
                return ProposalStatus.Succeeded;
            } else {
                return ProposalStatus.Defeated;
            }
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
    ) public onlyDebondOperator {
        IGovStorage(govStorageAddress).setThreshold(_newThreshold, _executor);
    }

    /**
    * @dev return the proposal threshold
    */
    function getProposalThreshold() public view returns(uint256) {
        return IGovStorage(govStorageAddress).getThreshold();
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
        day = IVoteCounting(voteCountingAddress).getVotingDay(_class, _nonce, _msgSender());
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
        interest = (
            _amount * IGovStorage(govStorageAddress).getInterestForStakingDGOV() * _duration
        ) / (100 * IGovStorage(govStorageAddress).getNumberOfSecondInYear());
    }

    /**
    * @dev generate a new nonce for a given class
    * @param _class proposal class
    */
    function _generateNewNonce(uint128 _class) internal returns(uint128 nonce) {
        nonce = IGovStorage(govStorageAddress).getProposalNonce(_class) + 1;
        IGovStorage(govStorageAddress).setProposalNonce(_class, nonce);
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
    * @dev get the bnumber of days elapsed since the vote has started
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param day the current voting day
    */
    function _getVotingDay(uint128 _class, uint128 _nonce) internal view returns(uint256 day) {
        Proposal memory _proposal = IGovStorage(
            govStorageAddress
        ).getProposalStruct(_class, _nonce);

        uint256 duration = _proposal.startTime > block.timestamp ?
            0: block.timestamp - _proposal.startTime;
        
        day = (duration / IGovStorage(govStorageAddress).getNumberOfSecondInYear()) + 1;
    }
    
    /**********************************************************************************
    * External Executable functions (used to change params in contracts like Bank, etc)
    **********************************************************************************/  
    function setMaxSupply(
        uint256 maxSupply
    ) public onlyDebondOperator returns (bool) {
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
    ) public onlyDebondOperator onlyDBITorDGOV(_tokenAddress) returns (bool) {
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
    ) public onlyDebondOperator onlyDBITorDGOV(_tokenAddress) returns (bool) {
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
    ) public onlyDebondOperator onlyDBITorDGOV(_tokenAddress) returns(bool) {
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
    ) public onlyDebondOperator onlyDBITorDGOV(_tokenAddress) returns(bool) {
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
    ) public onlyDebondOperator onlyDBITorDGOV(_tokenAddress) returns(bool) {
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
    ) public onlyDebondOperator returns(bool) {
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
    ) public onlyDebondOperator returns(bool) {
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
    ) public onlyDebondOperator returns(bool) {
        IExchangeStorage(
            IGovStorage(govStorageAddress).getExchangeStorageAddress()
        ).setMinAuctionDuration(_minAuctionDuration);

        return true;
    }
}