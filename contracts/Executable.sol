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

import "@debond-protocol/debond-token-contracts/interfaces/IDebondToken.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IGovStorage.sol";
import "./interfaces/IGovSharedStorage.sol";
import "./interfaces/IVoteCounting.sol";
import "./interfaces/IExecutable.sol";

contract Executable is IExecutable, IGovSharedStorage {
    address public govStorageAddress;
    address public voteCountingAddress;

    modifier onlyDebondOperator {
        require(
            msg.sender == IGovStorage(govStorageAddress).getDebondOperator(),
            "Executable: permission denied"
        );
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

    constructor(
        address _govStorageAddress,
        address _voteCountingAddress
    ) {
        govStorageAddress = _govStorageAddress;
        voteCountingAddress = _voteCountingAddress;
    }

    /**
    * @dev set gov storage address
    */
    function setGovStorageAddress(
        address _newGovStorageAddress
    ) public onlyDebondOperator {
        require(
            _newGovStorageAddress != address(0), "Executable: zero address"
        );

        govStorageAddress = _newGovStorageAddress;
    }

    /**********************************************************************************
    *         Executable functions (executed only after a proposal has passed)
    **********************************************************************************/

    /**
    * @dev update the governance contract
    * @param _newGovernanceAddress new address for the Governance contract
    */
    function updateGovernanceContract(
        address _newGovernanceAddress,
        address _executor
    ) external onlyDebondExecutor(_executor) returns(bool) {
        require(
            _newGovernanceAddress != address(0), "Executable: zero address"
        );

        IGovStorage(govStorageAddress).updateGovernanceContract(_newGovernanceAddress, _executor);

        return true;
    }

    /**
    * @dev update the exchange contract
    * @param _newExchangeAddress new address for the Exchange contract
    */
    function updateExchangeContract(
        address _newExchangeAddress,
        address _executor
    ) external onlyDebondExecutor(_executor) returns(bool) {
        require(
            _newExchangeAddress != address(0), "Executable: zero address"
        );

        IGovStorage(govStorageAddress).updateExchangeContract(_newExchangeAddress, _executor);

        return true;
    }

    /**
    * @dev update the bank contract
    * @param _newBankAddress new address for the Bank contract
    */
    function updateBankContract(
        address _newBankAddress,
        address _executor
    ) external onlyDebondExecutor(_executor) returns(bool) {
        require(
            _newBankAddress != address(0), "Executable: zero address"
        );

        IGovStorage(govStorageAddress).updateBankContract(_newBankAddress, _executor);

        return true;
    }

    /**
    * @dev update the benchmark interest rate
    * @param _newBenchmarkInterestRate new benchmark interest rate
    */
    function updateBenchmarkInterestRate(
        uint256 _newBenchmarkInterestRate
    ) external returns(bool) {
        IGovStorage(govStorageAddress).setBenchmarkIR(_newBenchmarkInterestRate);

        return true;
    }

    /**
    * @dev change the community fund size (DBIT, DGOV)
    * @param _newDBITBudgetPPM new DBIT budget for community
    * @param _newDGOVBudgetPPM new DGOV budget for community
    */
    function changeCommunityFundSize(
        uint128 _proposalClass,
        uint256 _newDBITBudgetPPM,
        uint256 _newDGOVBudgetPPM
    ) external returns(bool) {
        require(_proposalClass < 1, "Executable: class not valid");

        IGovStorage(govStorageAddress).setFundSize(_newDBITBudgetPPM, _newDGOVBudgetPPM);

        return true;
    }

    /**
    * @dev change the team allocation - (DBIT, DGOV)
    * @param _to the address that should receive the allocation tokens
    * @param _newDBITPPM the new DBIT allocation
    * @param _newDGOVPPM the new DGOV allocation
    */
    function changeTeamAllocation(
        address _to,
        uint256 _newDBITPPM,
        uint256 _newDGOVPPM
    ) external returns(bool) {
        require(
            _checkSupply(_to, _newDBITPPM, _newDGOVPPM),
            "Executable: Fails, not enough supply"
        );

        IGovStorage(govStorageAddress).setTeamAllocation(_to, _newDBITPPM, _newDGOVPPM);

        return true;
    }

    /**
    * @dev mint allocated DBIT to a given address
    * @param _to the address to mint DBIT to
    * @param _amountDBIT the amount of DBIT to mint
    * @param _amountDGOV the amount of DGOV to mint
    */
    function mintAllocatedToken(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) external returns(bool) {
        require(
            _checkSupply(_to, _amountDBIT, _amountDGOV),
            "Executable: Fails, not enough supply"
        );

        IGovStorage(govStorageAddress).mintAllocatedToken(_to, _amountDBIT, _amountDGOV);

        return true;
    }

    /**
    * @dev claim fund for a proposal
    * @param _to address to transfer fund
    * @param _amountDBIT DBIT amount to transfer
    * @param _amountDGOV DGOV amount to transfer
    */
    function claimFundForProposal(
        uint128 _proposalClass,
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) external returns(bool) {
        require(_proposalClass <= 2, "Gov: class not valid");

        IGovStorage(govStorageAddress).claimFundForProposal(_to, _amountDBIT, _amountDGOV);

        return true;
    }

    /**
    * @dev migrate tokens from an address to another address
    * @param _class proposal class
    * @param _token token address
    * @param _from sender address
    * @param _to recepient address
    * @param _amount amount of tokens to transfer
    */
    /*
    function migrateTokens(
        uint128 _class,
        address _token,
        address _from,
        address _to,
        uint256 _amount
    ) external returns(bool) {
        require(_class <= 1, "Executable: invalid proposal class");

        return true;
    }
    */


    /**
    * @dev internal function to check DBIT and DGOV supply
    * @param _to the recipient in mintAllocatedToken and changeTeamAllocation
    * @param _amountDBIT amount of DBIT to mint or new DBIT allocation percentage
    * @param _amountDGOV amount of DGOV to mint or new DGOV allocation percentage
    */
    function _checkSupply(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) internal view returns(bool) {
        (
            uint256 dbitAllocPPM,
            uint256 dgovAllocPPM
        ) = IGovStorage(govStorageAddress).getAllocatedToken(_to);
       
        require(
            IDebondToken(
                IGovStorage(govStorageAddress).getDBITAddress()
            ).getAllocatedBalance(_to) + _amountDBIT <=
            IDebondToken(
                IGovStorage(govStorageAddress).getDBITAddress()
            ).getTotalCollateralisedSupply() * dbitAllocPPM / 1 ether,
            "Executable: Not enough DBIT supply"
        );

        require(
            IDebondToken(
                IGovStorage(govStorageAddress).getDGOVAddress()
            ).getAllocatedBalance(_to) + _amountDGOV <=
            IDebondToken(
                IGovStorage(govStorageAddress).getDGOVAddress()
            ).getTotalCollateralisedSupply() * dgovAllocPPM / 1 ether,
            "Executable: not enough DGOV supply"
        );

        return true;
    }
}