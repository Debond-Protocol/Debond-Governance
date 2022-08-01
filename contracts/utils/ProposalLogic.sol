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
import "../interfaces/IGovStorage.sol";
import "../interfaces/IVoteToken.sol";
import "../interfaces/IStaking.sol";
import "../interfaces/IVoteCounting.sol";
import "../interfaces/IGovSettings.sol";
import "../interfaces/IProposalLogic.sol";
import "../interfaces/IGovSharedStorage.sol";

contract ProposalLogic is IProposalLogic {
    address vetoOperator;
    address govStorageAddress;
    address voteTokenAddress;
    address stakingAddress;
    address voteCountingAddress;

    modifier onlyVetoOperator {
        require(msg.sender == vetoOperator, "ProposalLogic: permission denied");
        _;
    }

    modifier onlyGov() {
        require(
            msg.sender == IGovStorage(govStorageAddress).getGovernanceAddress(),
            "ProposalLogic: Only Gov"
        );
        _;
    }

    constructor(
        address _vetoOperator,
        address _govStorageAddress,
        address _voteTokenAddress,
        address _voteCountingAddress
    ) {
        vetoOperator = _vetoOperator;
        govStorageAddress = _govStorageAddress;
        voteTokenAddress = _voteTokenAddress;
        voteCountingAddress = _voteCountingAddress;
    }

    /**
    * @dev see {INewGovernance} for description
    * @param _class proposal class
    * @param _targets array of contract to interact with if the proposal passes
    * @param _values array contraining ethers to send (can be array of zeros)
    * @param _calldatas array of encoded functions to call if the proposal passes
    * @param _title proposal title
    */
    function setProposalData(
        uint128 _class,
        address _proposer,
        address[] memory _targets,
        uint256[] memory _values,
        bytes[] memory _calldatas,
        string memory _title
    ) external onlyGov returns(
        uint128 nonce,
        uint256 start,
        uint256 end,
        ProposalApproval approval
    ) {
        require(
            IVoteToken(
                IGovStorage(govStorageAddress).getVoteTokenContract()
            ).availableBalance(_proposer) >=
            IGovStorage(govStorageAddress).getThreshold(),
            "Gov: insufficient vote tokens"
        );

        require(
            _targets.length == _values.length &&
            _values.length == _calldatas.length,
            "Gov: invalid proposal"
        );
 
        nonce = _generateNewNonce(_class);     
        approval = getApprovalMode(_class);

        IVoteToken(
            IGovStorage(govStorageAddress).getVoteTokenContract()
        ).lockTokens(
            _proposer,
            _proposer,
            IGovStorage(govStorageAddress).getThreshold(),
            _class,
            nonce
        );

        start = block.timestamp + IGovSettings(
            IGovStorage(govStorageAddress).getGovSettingContract()
        ).votingDelay();
        
        end = start + IGovSettings(
            IGovStorage(govStorageAddress).getGovSettingContract()
        ).votingPeriod();

        IGovStorage(govStorageAddress).setProposal(
            _class,
            nonce,
            start,
            end,
            _proposer,
            approval,
            _targets,
            _values,
            _calldatas,
            _title
        );
    }

    /**
    * @dev check and set proposal status when executing a proposal
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function checkAndSetProposalStatus(
        uint128 _class,
        uint128 _nonce
    ) external onlyGov {
        ProposalStatus status = IGovStorage(
            govStorageAddress
        ).getProposalStatus(_class, _nonce);

        require(
            status == ProposalStatus.Succeeded,
            "Gov: proposal not successful"
        );
        
        IGovStorage(
            govStorageAddress
        ).setProposalStatus(_class, _nonce, ProposalStatus.Executed);
    }

    /**
    * @dev execute a proposal
    * @param _class proposal class
    * @param _nonce proposal nonce
    */
    function cancelProposal(
        uint128 _class,
        uint128 _nonce
    ) external onlyGov {
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
    }

    function voteRequirement(
        uint128 _class,
        uint128 _nonce,
        address _tokenOwner,
        address _voter,
        uint256 _amountVoteTokens,
        uint256 _stakingCounter
    ) external onlyGov {
        require(_voter != address(0), "Governance: zero address");
        require(_class >= 0 && _nonce > 0, "Gov: invalid proposal");

        uint256 _dgovStaked = IStaking(
            IGovStorage(govStorageAddress).getStakingContract()
        ).getStakedDGOV(_tokenOwner, _stakingCounter);
        
        uint256 approvedToSpend = IERC20(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).allowance(_tokenOwner, _voter);
        
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
        ).lockTokens(_tokenOwner, _voter, _amountVoteTokens, _class, _nonce);
    }

    function unstakeDGOVandCalculateInterest(
        address _staker,
        uint256 _stakingCounter
    ) external onlyGov returns(uint256 amountStaked, uint256 interest) {
        amountStaked = IStaking(
            IGovStorage(govStorageAddress).getStakingContract()
        ).unstakeDgovToken(_staker, _stakingCounter);

        // the interest calculated from this function is in ether unit
        interest = IStaking(
            IGovStorage(govStorageAddress).getStakingContract()
        ).calculateInterestEarned(
            _staker,
            _stakingCounter,
            IGovStorage(govStorageAddress).getInterestForStakingDGOV()
        );
    }

    /**
    * @dev internal unlockVoteTokens function
    * @param _class proposal class
    * @param _nonce proposal nonce
    * @param _tokenOwner owner of vote tokens
    */
    function unlockVoteTokens(
        uint128 _class,
        uint128 _nonce,
        address _tokenOwner
    ) external onlyGov {
        Proposal memory _proposal = IGovStorage(
            govStorageAddress
        ).getProposalStruct(_class, _nonce);

        require(
            block.timestamp > _proposal.endTime,
            "Gov: still voting"
        );

        if(
            _tokenOwner != IGovStorage(govStorageAddress).getProposalProposer(_class, _nonce)
        ) {
            require(
                IVoteCounting(voteCountingAddress).hasVoted(_class, _nonce, _tokenOwner),
                "Gov: you haven't voted"
            );
        }
        
        uint256 _amount = IVoteToken(
            IGovStorage(govStorageAddress).getVoteTokenContract()
        ).lockedBalanceOf(_tokenOwner, _class, _nonce);

        IVoteToken(
            IGovStorage(govStorageAddress).getVoteTokenContract()
        ).unlockTokens(_tokenOwner, _amount, _class, _nonce);
    }

    function transferInterest(
        uint128 _class,
        uint128 _nonce,
        address _tokenOwner
    ) external onlyGov returns(uint256 reward) {
        require(
            !IVoteCounting(voteCountingAddress).hasBeenRewarded(_class, _nonce, _tokenOwner),
            "Gov: already rewarded"
        );
        IVoteCounting(voteCountingAddress).setUserHasBeenRewarded(_class, _nonce, _tokenOwner);

        uint256 _reward;
        
        for(uint256 i = 1; i <= IGovStorage(govStorageAddress).getNumberOfVotingDays(_class); i++) {
            _reward += (1 ether * 1 ether) / IGovStorage(govStorageAddress).getTotalVoteTokenPerDay(_class, _nonce, i);
        }

        reward = _reward * IVoteCounting(voteCountingAddress).getVoteWeight(_class, _nonce, _tokenOwner) * 
                  IGovStorage(govStorageAddress).getNumberOfDBITDistributedPerDay(_class) / 1 ether;
    }

    function vote(
        uint128 _class,
        uint128 _nonce,
        address _voter,
        uint8 _userVote,
        uint256 _amountVoteTokens
    ) external onlyGov {
        require(
            IGovStorage(
                govStorageAddress
            ).getProposalStatus(_class, _nonce) == ProposalStatus.Active,
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

    function setStakingContract(address _stakingAddress) public onlyVetoOperator {
        stakingAddress = _stakingAddress;
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
}