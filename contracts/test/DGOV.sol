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

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


interface IDebondTokenDGOV  {
    function totalSupply() external view returns (uint256);

    function airdropedSupply() external view returns (uint256);

    function allocatedSupply() external view returns (uint256);

    function collaterisedSupply() external returns(uint256);

    function collateralisedBalance(address _user) external view returns(uint256 balance);

    function airdroppedBalance(address _user) external view returns(uint256 balance);

    function allocatedBalance(address _user) external view returns(uint256 balance);

    function mintCollateralisedSupply(address _to, uint256 _amount) external ;

    function mintAllocatedSupply(address _to, uint256 _amount) external  ; 

    function mintAirdroppedSupply(address _to, uint256 _amount) external;
        
    function setBankContract(address bank_addres) external returns (bool);

    function directTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) external  returns (bool);
    function setAirdroppedSupply(uint256 new_supply) external returns(bool); 
}

interface ICollateralDGOV {
    function collaterisedSupply() external view returns (uint);
}


contract DGOV is ERC20, IDebondTokenDGOV, AccessControl, ICollateralDGOV {
    // this minter role will be for airdropToken , bank or the governance Contract
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    uint256 public _collateralisedSupply;
    uint256 public _allocatedSupply;
    uint256 public _airdroppedSupply;
    bool isActive;
    
    address bankAddress;
    address governanceAddress;
    address _exchangeAddress;
    address _airdropAddress;

    // checks locked supply.
    //@yu SOME VARIBLES IS NOT INTERNAL AND SOME IS
    mapping(address => uint256) public _collateralisedBalance;
    mapping(address => uint256) public _allocatedBalance;
    mapping(address => uint256) public _airdroppedBalance;

    /** currently setting only the main token parameters , and once the other contracts are deployed then use setContractAddress to set up these contracts.
    */

    constructor() ERC20("Debond Governance Token", "DGOV") {}

    /**
    * @dev return the total supply of DBIT
    */
    function totalSupply()
        public
        view
        virtual
        override(ERC20, IDebondTokenDGOV)
        returns (uint256)
    {
        return
            _allocatedSupply +
            _collateralisedSupply +
            _airdroppedSupply;
    }

    /**
    * @dev return the the total allocated supplly
    */
    function allocatedSupply() public view override returns (uint256) {
        return _allocatedSupply;
    }

    // just an contract for formality given that current version doesnt have to be minted for DBIT.
    function airdropedSupply() public view override returns (uint256) {
        return _airdroppedSupply;
    }

    /**
    * @dev return the collateralized of a given account
    * @param _user the user address
    * @param balance collateralized balance of `_user`
    */
    function collateralisedBalance(address _user) public view override returns(uint256 balance) {
        balance = _collateralisedBalance[_user];
    }

    /**
    * @dev return the airdrop of a given account
    * @param _user the user address
    * @param balance airdrop balance of `_user`
    */
    function airdroppedBalance(address _user) public view override returns(uint256 balance) {
        balance = _airdroppedBalance[_user];
    }

    /**
    * @dev return the allocated of a given account
    * @param _user the user address
    * @param balance allocated balance of `_user`
    */
    function allocatedBalance(address _user) public view override returns(uint256 balance) {
        balance = _allocatedBalance[_user];
    }

    function collaterisedSupply()
        external
        view
        override(ICollateralDGOV, IDebondTokenDGOV)
        returns (uint256)
    {
        return _collateralisedSupply;
    }

    function IsActive(bool status) public    returns(bool) {   
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        isActive = status;
        return true;
    }

    function LockedBalance(address account) external view returns (uint256) {
        
        uint lockedBalance =  (1-(20 * _collateralisedSupply  / _airdroppedSupply)) * _airdroppedBalance[account];
        return lockedBalance  < 0  ? 0 : lockedBalance ;

    }

    function _checkIfItsLockedSupply(address from, uint256 amountToTransfer)
        internal
        view
        returns (bool)
    {
        return ((balanceOf(from) - this.LockedBalance(from)) >=
            amountToTransfer);
    }

    // We need a transfer and transfer from function to replace the standarded ERC 20 functions.
    // In our functions we will be verifying if the transfered ammount <= balance - locked supply

    //bank transfer can only be called by bank contract or exchange contract, bank transfer don't need the approval of the sender.
    function directTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) public  override returns (bool) {
        require(msg.sender == _exchangeAddress || msg.sender == bankAddress );

        require(_checkIfItsLockedSupply(_from, _amount), "insufficient supply");

        _transfer(_from, _to, _amount);
        return (true);
    }

    /**
     */
    function mintCollateralisedSupply(address _to, uint256 _amount)
        external
        virtual
        override
    {
        require(msg.sender == bankAddress, "only Bank");
        _mint(_to, _amount);
        _collateralisedSupply += _amount;
        _collateralisedBalance[_to] += _amount;
    }

    function mintAllocatedSupply(address _to, uint256 _amount)
        external
        override
    {
        require(msg.sender == governanceAddress, "only Gov");
        _mint(_to, _amount);
        _allocatedSupply += _amount;
        _allocatedBalance[_to] += _amount;
    }

    function mintAirdroppedSupply(address _to, uint256 _amount)
        external
        override
    {
        require(msg.sender == governanceAddress, "only Gov");
        _mint(_to, _amount);
        _airdroppedSupply += _amount;
        _airdroppedBalance[_to] += _amount;
    }


    function setBankContract(address _bankAddress) public override returns (bool) {
        //require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "only DeBond");
        bankAddress = _bankAddress;
        return (true);
    }

    function setExchangeContract(address exchange_address)
        public
        returns (bool)
    {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "only DeBond");
        _exchangeAddress = exchange_address;
        return (true);
    }


    function setAirdropContract(address new_Airdrop) public returns (bool) {
    require(msg.sender == _airdropAddress, "only airdop contract");
    _airdropAddress = new_Airdrop;
    return (true);
}

     function setAirdroppedSupply(uint256 new_supply) public override returns (bool) {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "DBIT: ACCESS DENIED "
        );
        _airdroppedSupply = new_supply;

        return true;
    }

    function setGovernanceContract(address _governance) external {
        governanceAddress = _governance;
    }

}