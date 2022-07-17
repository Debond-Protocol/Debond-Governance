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
import "./GovStorage.sol";
import "./interfaces/IExecutable.sol";

contract Executable is GovStorage, IExecutable {
    constructor(
        address _debondTeam,
        address _dbitContract,
        address _dgovContract
    ) {
        dbitContract = _dbitContract;
        dgovContract = _dgovContract;

        debondTeam = _debondTeam;

        // in percent
        benchmarkInterestRate = 5;

        dbitBudgetPPM = 1e5 * 1 ether;
        dgovBudgetPPM = 1e5 * 1 ether;

        allocatedToken[debondTeam].dbitAllocationPPM = 4e4 * 1 ether;
        allocatedToken[debondTeam].dgovAllocationPPM = 8e4 * 1 ether;
    }

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
    */
    function updateBenchmarkInterestRate(
        uint256 _newBenchmarkInterestRate
    ) public returns(bool) {
        benchmarkInterestRate = _newBenchmarkInterestRate;

        return true;
    }

    /**
    * @dev change the community fund size (DBIT, DGOV)
    * @param _newDBITBudgetPPM new DBIT budget for community
    * @param _newDGOVBudgetPPM new DGOV budget for community
    */
    function changeCommunityFundSize(
        uint256 _newDBITBudgetPPM,
        uint256 _newDGOVBudgetPPM
    ) public returns(bool) {
        dbitBudgetPPM = _newDBITBudgetPPM;
        dgovBudgetPPM = _newDGOVBudgetPPM;

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
    ) public returns(bool) {
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
    */
    function mintAllocatedToken(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) public returns(bool) {
        AllocatedToken memory _allocatedToken = allocatedToken[_to];
        
        uint256 _dbitCollaterizedSupply = IDebondToken(dbitContract).getTotalCollateralisedSupply();
        uint256 _dgovCollaterizedSupply = IDebondToken(dgovContract).getTotalCollateralisedSupply();
        
        require(
            IDebondToken(dbitContract).getAllocatedBalance(_to) + _amountDBIT <=
            _dbitCollaterizedSupply * _allocatedToken.dbitAllocationPPM / 1 ether,
            "Gov: not enough supply"
        );
        require(
            IDebondToken(dgovContract).getAllocatedBalance(_to) + _amountDGOV <=
            _dgovCollaterizedSupply * _allocatedToken.dgovAllocationPPM / 1 ether,
            "Gov: not enough supply"
        );
        
        allocatedToken[_to].allocatedDBITMinted += _amountDBIT;
        dbitTotalAllocationDistributed += _amountDBIT;

        allocatedToken[_to].allocatedDGOVMinted += _amountDGOV;
        dgovTotalAllocationDistributed += _amountDGOV;

        return true;
    }

    /**
    * @dev claim fund for a proposal
    * @param _to address to transfer fund
    * @param _amountDBIT DBIT amount to transfer
    * @param _amountDGOV DGOV amount to transfer
    */
    function claimFundForProposal(
        address _to,
        uint256 _amountDBIT,
        uint256 _amountDGOV
    ) public returns(bool) {
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
        
        allocatedToken[_to].allocatedDBITMinted += _amountDBIT;
        dbitTotalAllocationDistributed += _amountDBIT;

        allocatedToken[_to].allocatedDGOVMinted += _amountDGOV;
        dgovTotalAllocationDistributed += _amountDGOV;

        return true;
    }

    /**
    * @dev return DBIT address
    */
    function getDBITAddress() public view returns(address) {
        return dbitContract;
    }

    /**
    * @dev return DGOV address
    */
    function getDGOVAddress() public view returns(address) {
        return dgovContract;
    }

    /**
    * @dev return Bank address
    */
    function getBankAddress() public view returns(address) {
        return bankContract;
    }
    
    /**
    * @dev return Exchange address
    */
    function getExchangeAddress() public view returns(address) {
        return exchangeContract;
    }

    /**
    * @dev return Governance address
    */
    function getGovernanceAddress() public view returns(address) {
        return governance;
    }

    /**
    * @dev return the Debond team address
    */
    function getDebondTeamAddress() public view returns(address) {
        return debondTeam;
    }

    /**
    * @dev return the benchmark interest rate
    */
    function getBenchmarkInterestRate() public view returns(uint256) {
        return benchmarkInterestRate;
    }

    /**
    * @dev return DBIT and DGOV budgets in PPM (part per million)
    */
    function getBudget() public view returns(uint256, uint256) {
        return (dbitBudgetPPM, dgovBudgetPPM);
    }

    /**
    * return DBIT and DGOV allocation distributed
    */
    function getAllocationDistributed() public view returns(uint256, uint256) {
        return (dbitAllocationDistibutedPPM, dgovAllocationDistibutedPPM);
    }

    /**
    * return DBIT and DGOV total allocation distributed
    */
    function getTotalAllocationDistributed() public view returns(uint256, uint256) {
        return (
            dbitTotalAllocationDistributed,
            dgovTotalAllocationDistributed
        );
    }

    /**
    * @dev return the amount of DBIT and DGOV allocated to an address
    */
    function getAllocatedToken(address _account) public view returns(uint256, uint256) {
        return (
            allocatedToken[_account].dbitAllocationPPM,
            allocatedToken[_account].dgovAllocationPPM
        );
    }

    /**
    * @dev return the amount of allocated DBIT and DGOV minted to an address
    */
    function getAllocatedTokenMinted(address _account) public view returns(uint256, uint256) {
        return (
            allocatedToken[_account].allocatedDBITMinted,
            allocatedToken[_account].allocatedDGOVMinted
        );
    }
}