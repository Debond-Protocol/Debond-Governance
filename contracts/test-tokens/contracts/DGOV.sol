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

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "./interfaces/IdGOV.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "@openzeppelin/contracts/access/AccessControl.sol";

import "debond-governance/contracts/utils/GovernanceOwnable.sol";


contract DGOV is ERC20Capped, Ownable, IdGOV, AccessControl , GovernanceOwnable  {
    uint256 public _maximumSupply;
    uint256  internal _collateralisedSupply; // this will be  call by bank contract
    uint256  internal  _allocatedSupply; // this corresponds to the tokens tallocated by governance , the functions to set this value will be called in proposal.
    uint256  internal _airdropedSupply; // set by the airdropedToken , decreases when people call mintAirdrop.
    uint256  internal _lockedSupply; // this will be storing total supply locked by hte airdrop



    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    using SafeMath for uint256;

    address _bankAddress;
    address _governanceAddress;
    address _exchangeAddress;
    address _airdropAddress; // address of DBITCreditAirdrop.

    // checks locked supply.
    mapping(address => uint256) internal lockedBalance;
    mapping(address => uint256)  internal _airdropedBalance;
    mapping(address => uint256) internal  _allocatedBalance;
    mapping(address => uint256) internal _unlockedBalance;

    modifier onlyAirdropToken() {
        require(msg.sender == _airdropAddress, "access denied");
        _;
    }

    /**

    */

    constructor(address governanceAddress) ERC20Capped(10**18) ERC20("DGOV", "DGOV") GovernanceOwnable(governanceAddress) {
        _maximumSupply = cap();
        _governanceAddress = governanceAddress;
    }


    function totalSupply() public view override returns (uint256) {
        return _collateralisedSupply + _allocatedSupply + _airdropedSupply;
    }
   
    // gets the amount of the lockedBalance for an given address
    function LockedBalance(address account) public view returns (uint256 _lockedBalance) {
         uint ratio = _collateralisedSupply/( 2e9 * _airdropedSupply );
        if( 1e8 <= ratio ){
            _lockedBalance = 0;
        }

         _lockedBalance =  (1e8 - ratio ) * _airdropedBalance[account] / 1e8;
    }

    // Check if supply is locked function, this will be called by the transfer  function
    function _checkIfItsLockedSupply(address account, uint256 amountTransfer)
        internal
        returns (bool)
    {
        return
            (balanceOf(account) - this.LockedBalance(account)) >=
            amountTransfer;
    }

    // read functions get the according amount of the supply.

    function allocatedSupply() public view returns (uint256) {
        return _allocatedSupply;
    }

    function AirdropedSupply() public view returns (uint256) {
        return _airdropedSupply;
    }

    function supplyCollateralised() external view returns (uint256) {
        return _collateralisedSupply;
    }


    function transfer(address _to ,  uint _amount)    public  override(IdGOV,ERC20) returns(bool) {
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
    ) public returns (bool) {
        require(
            msg.sender == _exchangeAddress ||
                msg.sender == _bankAddress  , "not available"
        );
        require(
            _checkIfItsLockedSupply(_from, _amount) == true,
            "insufficient supply"
        );
        transferFrom(_from, _to, _amount);
        return (true);
    }

    // Must be sent from the airdrop contract address which is defined in the constructor
    function mintAirdropedSupply(address _to, uint256 _amount) external {
        require(msg.sender == _airdropAddress);
        _mint(_to, _amount);

        _airdropedSupply -= _amount;
        // as the airdroped supply is minted it will be seperate from the each investors lockedBalance.
        _airdropedBalance[_to] += _amount;
    }

    /**
     */
    function mintCollateralisedSupply(address _to, uint256 _amount) external {
        require(msg.sender == _bankAddress);
        _mint(_to, _amount);
        _collateralisedSupply += _amount;
    }

    function mintAllocatedSupply(address _to, uint256 _amount) external {
        require(msg.sender == _airdropAddress);
        _mint(_to, _amount);
        _allocatedSupply += _amount;
    }

  
    
    /** allows to set the airdrop supply after the initialisation just in case.
     */
    function setAirdroppedSupply(uint256 new_supply) public returns (bool) {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "DGOV: ACCESS DENIED "
        );
        _airdropedSupply = new_supply;
    }

    function setMaximumSupply(uint maximumSupply) external onlyGovernance {
        _maximumSupply = maximumSupply;
    }



}