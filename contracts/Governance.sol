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
import "./interfaces/IGovSharedStorage.sol";
import "./interfaces/ITransferDBIT.sol";
import "./utils/GovernanceMigrator.sol";
import "./Pausable.sol";

/**
* @author Samuel Gwlanold Edoumou (Debond Organization)
*/
contract Governance is GovernanceMigrator, ReentrancyGuard, Pausable, IGovSharedStorage, ITransferDBIT {
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

    modifier onlyStaking {
        require(
            msg.sender == IGovStorage(govStorageAddress).getStakingContract(),
            "Gov: Only staking contract"
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
        // proposer must have a required minimum amount of vote tokens available -to be locked-
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

        // set the proposal data in gov storage
        uint128 nonce = IGovStorage(govStorageAddress).setProposal(
            _class,
            msg.sender,
            _targets,
            _values,
            _calldatas,
            _title,
            _descriptionHash
        );

        // lock the proposer vote tokens
        IVoteToken(
            IGovStorage(govStorageAddress).getVoteTokenContract()
        ).lockTokens(
            msg.sender,
            msg.sender,
            IGovStorage(govStorageAddress).getProposalThreshold(),
            _class,
            nonce
        );

        emit ProposalCreated(_class, nonce);
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
        ).setProposalStatus(_class, _nonce, ProposalStatus.Executed);

        _execute(proposal.targets, proposal.ethValue, proposal.calldatas);

        emit ProposalExecuted(_class, _nonce);
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
        IGovStorage(govStorageAddress).cancel(_class, _nonce, msg.sender);

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
        require(voter != address(0), "Gov: zero address");
        require(_tokenOwner != address(0), "Gov: zero address");
        require(
            IGovStorage(
                govStorageAddress
            ).getProposalStatus(_class, _nonce) == ProposalStatus.Active,
            "Gov: vote not active"
        ); 

        IVoteToken(
            IGovStorage(govStorageAddress).getVoteTokenContract()
        ).lockTokens(_tokenOwner, voter, _amountVoteTokens, _class, _nonce);     

        IGovStorage(govStorageAddress).setVote(_class, _nonce, voter, _userVote, _amountVoteTokens);

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
        require(
            msg.sender != address(0) && msg.sender == IGovStorage(govStorageAddress).getVetoOperator(),
            "Gov: only veto operator"
        );
        require(_class >= 0 && _nonce > 0, "Gov: invalid proposal");
        require(
            IGovStorage(
                govStorageAddress
            ).getProposalStatus(_class, _nonce)  == ProposalStatus.Active,
            "Gov: vote not active"
        );

        IGovStorage(govStorageAddress).setVeto(_class, _nonce, _veto);

        emit vetoUsed(_class, _nonce);
    }

    /**
    * @dev transfer DBIT interests from APM to a user account
    * @param _account user account address
    * @param _interest amount of DBIT to transfer
    */
    function transferDBITInterests(
        address _account,
        uint256 _interest
    ) external onlyStaking {
        IAPM(
            IGovStorage(govStorageAddress).getAPMAddress()
        ).removeLiquidity(
            _account,
            IGovStorage(govStorageAddress).getDBITAddress(),
            _interest
        );
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