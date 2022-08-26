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
import "@openzeppelin/contracts/utils/Address.sol";
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
    * @dev store proposal data
    * @param _class proposal class
    * @param _targets array of contract to interact with if the proposal passes
    * @param _values array contraining ethers to send (can be array of zeros)
    * @param _calldatas array of encoded functions to call if the proposal passes
    * @param _title proposal title
    */
    function _setProposalData(
        uint128 _class,
        uint128 _nonce,
        address _proposer, 
        address _targets,
        uint256 _values,
        bytes memory _calldatas,
        string memory _title
    ) private returns(
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

        /*
        require(
            _targets.length == _values.length &&
            _values.length == _calldatas.length,
            "Gov: invalid proposal"
        );
        */
     
        approval = getApprovalMode(_class);

        IVoteToken(
            IGovStorage(govStorageAddress).getVoteTokenContract()
        ).lockTokens(
            _proposer,
            _proposer,
            IGovStorage(govStorageAddress).getThreshold(),
            _class,
            _nonce
        );

        start = block.timestamp;
        
        end = start + IGovSettings(
            IGovStorage(govStorageAddress).getGovSettingContract()
        ).getVotingPeriod(_class);

        IGovStorage(govStorageAddress).setProposal(
            _class,
            _nonce,
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
    * @dev hash a proposal
    * @param _class proposal class
    * @param _targets array of target contracts
    * @param _values array of ether send
    * @param _calldatas array of calldata to be executed
    * @param _descriptionHash the hash of the proposal description
    */
    function hashProposal(
        uint128 _class,
        uint128 _nonce,
        address _targets,
        uint256 _values,
        bytes memory _calldatas,
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
        ).getStakedDGOVAmount(_tokenOwner, _stakingCounter);
        
        uint256 approvedToSpend = IERC20(
            IGovStorage(govStorageAddress).getDGOVAddress()
        ).allowance(_tokenOwner, _voter);
        
        require(
            _amountVoteTokens <= _dgovStaked &&
            _amountVoteTokens <= approvedToSpend,
            "ProposalLogic: not approved or not enough dGoV staked"
        );

        if (_voter != _tokenOwner) {
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
    }

    function unstakeDGOVandCalculateInterest(
        address _staker,
        uint256 _stakingCounter
    ) external onlyGov returns(uint256 amountStaked, uint256 interest, uint256 duration) {
        amountStaked = IStaking(
            IGovStorage(govStorageAddress).getStakingContract()
        ).unstakeDgovToken(_staker, _stakingCounter);

        // the interest calculated from this function is in ether unit
        (interest, duration) = IStaking(
            IGovStorage(govStorageAddress).getStakingContract()
        ).calculateInterestEarned(
            _staker,
            _stakingCounter,
            IGovStorage(govStorageAddress).stakingInterestRate()
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

        if(_tokenOwner != proposer) {
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

    function calculateReward(
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
                  IGovStorage(govStorageAddress).dbitDistributedPerDay() / (1 ether * 1 ether);
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

    function proposalSetUp(
        uint128 _class,
        uint128 _nonce,
        address _proposer,
        address _targets,
        uint256 _values,
        bytes memory _calldatas,
        string memory _title,
        bytes32 _descriptionHash
    ) public onlyGov returns(uint256 start, uint256 end, ProposalApproval approval) {
        (
            start,
            end,
            approval
        ) = 
        _setProposalData(
            _class, _nonce, _proposer, _targets, _values, _calldatas, _title
        );

        IGovStorage(
            govStorageAddress
        ).setProposalDescriptionHash(_class, _nonce, _descriptionHash);
    }

    function getUpdateDGOVMaxSupplyCallData(
        uint128 _class,
        uint128 _nonce,
        uint256 _maxSupply
    ) public pure returns(bytes memory) {
        bytes4 SELECTOR = bytes4(keccak256(bytes('updateDGOVMaxSupply(uint128,uint128,uint256)')));
        return abi.encodeWithSelector(SELECTOR, _class, _nonce, _maxSupply);
    }

    function getSetMaxAllocationPercentageCallData(
        uint128 _class,
        uint128 _nonce,
        uint256 _newPercentage,
        address _tokenAddress
    ) public pure returns(bytes memory) {
        bytes4 SELECTOR = bytes4(keccak256(bytes('setMaxAllocationPercentage(uint128,uint128,uint256,address)')));
        return abi.encodeWithSelector(SELECTOR, _class, _nonce, _newPercentage, _tokenAddress);
    }

    function getUpdateMaxAirdropSupplyCallData(
        uint128 _class,
        uint128 _nonce,
        uint256 _newSupply,
        address _tokenAddress
    ) public pure returns(bytes memory) {
        bytes4 SELECTOR = bytes4(keccak256(bytes('updateMaxAirdropSupply(uint128,uint128,uint256,address)')));
        return abi.encodeWithSelector(SELECTOR, _class, _nonce, _newSupply, _tokenAddress);
    }

    function getMintAllocatedTokenCallData(
        uint128 _class,
        uint128 _nonce,
        address _token,
        address _to,
        uint256 _amount
    ) public pure returns(bytes memory) {
        bytes4 SELECTOR = bytes4(keccak256(bytes('mintAllocatedToken(uint128,uint128,address,address,uint256)')));
        return abi.encodeWithSelector(SELECTOR, _class, _nonce, _token, _to, _amount);
    }
}