// SPDX-License-Identifier: apache 2.0

pragma solidity ^0.8.0;

import "../interfaces/IActivable.sol";
import "../interfaces/IGovernanceAddressUpdatable.sol";

contract GovernanceOwnable is IActivable, IGovernanceAddressUpdatable {

  
    address _debondOperator;
    address _airdropAddress;
    address _apmAddress;
    address _oracleAddress;
    address _dataAddress;
    address _dbitAddress;
    address _dgovAddress;
    address _exchangeAddress;
    address _bankAddress; 
     
     
    constructor(address _governanceAddress) {
        _debondOperator = _governanceAddress;
        isActive = true;
    }


    bool isActive;

    modifier onlyGovernance() {
        require(msg.sender == _debondOperator, "Governance Restriction: Not allowed");
        _;
    }

    modifier _onlyIsActive() {
        require(isActive, "Contract Is Not Active");
        _;
    }

    function setIsActive(bool _isActive) external onlyGovernance {
        isActive = _isActive;
    }

    function setGovernanceAddress(address _governanceAddress) external onlyGovernance {
        require(_governanceAddress != address(0), "null address given");
        _debondOperator = _governanceAddress;
    }
    
    
    function setAirdropAddress(address airdropAddress) external onlyGovernance {
        require(_airdropAddress != address(0), "null address given");
        _airdropAddress = airdropAddress;
    
    }
    
    function setAPMAddress(address  apmAddress) external onlyGovernance {
    require(apmAddress != address(0), "not null address" );
    _apmAddress = apmAddress;
    }
    
    function setDebondData(address  dataAddress) external onlyGovernance {
    require(dataAddress != address(0), "not null address" );
    _dataAddress = dataAddress;
    }
    
    function setOracle (address  _newOracle) external onlyGovernance {
    require(_newOracle != address(0), "not null address" );
    _oracleAddress = _newOracle;
    }
    
    function setDBITAddress(address dbitAddress) external onlyGovernance {
    require(dbitAddress != address(0), "not null address" );
    _dbitAddress = dbitAddress;
    }

    function  setDGOVAddress(address dgovAddress) external onlyGovernance {
    require( dgovAddress != address(0), "not null address" );
    _dgovAddress =  dgovAddress;
    }

    function  setBankAddress(address BankAddress) external onlyGovernance {
    require( BankAddress != address(0), "not null address" );
     _bankAddress =  BankAddress;
    }

    function  setExchangeAddress(address exchangeAddress) external onlyGovernance {
    require( exchangeAddress != address(0), "not null address" );
    _exchangeAddress = exchangeAddress;  
    }
}
