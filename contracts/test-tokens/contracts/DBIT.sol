pragma solidity ^0.8.0;

// SPDX-License-Identifier: apache 2.0
/*
    Copyright 2020 Sigmoid Foundation <info@SGM.finance>
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
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./interfaces/IDebondToken.sol";
import "./interfaces/ICollateral.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";

import "debond-governance/contracts/utils/GovernanceOwnable.sol";

contract DBIT is ERC20, IDebondToken, AccessControl, ICollateral , GovernanceOwnable {
    // this minter role will be for airdropToken , bank or the governance Contract
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public _collateralisedSupply;
    uint256 public _allocatedSupply;
    uint256 public _airdroppedSupply;
    
   // using DBIT for ERC20;
    address bankAddress;
    address exchangeAddress;
    address airdropAddress;

    bool state;

    // checks locked supply.
    //@yu SOME VARIBLES IS NOT INTERNAL AND SOME IS
    mapping(address => uint256) public collateralisedBalance;
    mapping(address => uint256) public allocatedBalance;
    mapping(address => uint256) public airdroppedBalance;

    /** currently setting only the main token parameters , and once the other contracts are deployed then use setContractAddress to set up these contracts.
     */

    constructor(address _governanceAddress) ERC20("DBIT Token", "DBIT") GovernanceOwnable(_governanceAddress) {
        

    }

    function collateralisedSupplyBalance(address _from) external returns (uint256)
    {   
        return collateralisedBalance[_from];
    }

    function airdroppedSupplyBalance(address _from) external returns (uint256)
    {   
        return airdroppedBalance[_from];
    }


    function allocatedSupplyBalance(address _from) external returns (uint256)
    {   
        return allocatedBalance[_from];
    }



    function totalSupply()
        public
        view
        virtual
        override(ERC20,IDebondToken)
        returns (uint256)
    {
        return
            _allocatedSupply +
            _collateralisedSupply +
            _airdroppedSupply;
    }

    function allocatedSupply() public view returns (uint256) {
        return _allocatedSupply;
    }

    // just an contract for formality given that current version doesnt have to be minted for DBIT.
    function airdropedSupply() public view returns (uint256) {
        return _airdroppedSupply;
    }


    function supplyCollateralised()
        public
        view
        override(ICollateral, IDebondToken)
        returns (uint256)
    {
        return _collateralisedSupply;
    }

    
    function LockedBalance(address account) public view returns (uint256 _lockedBalance) {
        uint ratio = _collateralisedSupply/( 2e9 * _airdroppedSupply );
        if( 1e8 <= ratio ){
            _lockedBalance = 0;
        }

         _lockedBalance =  (1e8 - ratio ) * airdroppedBalance[account] / 1e8;
    }

    function _checkIfItsLockedSupply(address from, uint256 amountToTransfer)
        internal
        view
        returns (bool)
    {
        return ((balanceOf(from) - this.LockedBalance(from)) >=
            amountToTransfer);
    }


    function transfer( address _to ,  uint _amount)    public   returns(bool) {
    require(_checkIfItsLockedSupply(msg.sender, _amount), "insufficient supply");
     _transfer(msg.sender, _to, _amount);
     return true;

    }


    // We need a transfer and transfer from function to replace the standarded ERC 20 functions.
    // In our functions we will be verifying if the transfered ammount <= balance - locked supply

    //bank transfer can only be called by bank contract or exchange contract, bank transfer don't need the approval of the sender.
    function directTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) public  override returns (bool) {
        require(msg.sender == exchangeAddress || msg.sender == bankAddress );

        require(_checkIfItsLockedSupply(_from, _amount), "insufficient supply");

        transfer(_from, _to, _amount);
        return (true);
    }

    /**
     */
    function mintCollateralisedSupply(address _to, uint256 _amount)
        public
        virtual
        override
    {
        require(msg.sender == bankAddress);
        _mint(_to, _amount);
        _collateralisedSupply += _amount;
        collateralisedBalance[_to] += _amount;
    }

    function mintAllocatedSupply(address _to, uint256 _amount)
        public
        override
    {
        require(msg.sender == governanceAddress);
        _mint(_to, _amount);
        _allocatedSupply += _amount;
        allocatedBalance[_to] += _amount;
    }

    function mintAirdroppedSupply(address _to, uint256 _amount)
        public
        override
    {
        require(msg.sender == airdropAddress);
        _mint(_to, _amount);
        airdroppedBalance[_to] += _amount;
    }



    function setAirdroppedSupply(uint256 new_supply) public returns(bool)
    {   hasRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _airdroppedSupply = new_supply;
    }


}