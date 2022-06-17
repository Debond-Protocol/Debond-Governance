// SPDX-License-Identifier: apache 2.0

pragma solidity ^0.8.0;

import "../interfaces/IActivable.sol";
import "../interfaces/IGovernanceAddressUpdatable.sol";

contract GovernanceOwnable is IActivable, IGovernanceAddressUpdatable {

    constructor(address _governanceAddress) {
        governanceAddress = _governanceAddress;
        isActive = true;
    }

    address governanceAddress;
    address airdropAddress;
    address apmAddress;
    address oracleAddress;
    address dataAddress;
    address dbitAddress;
    address dgovAddress;
    
    bool isActive;

    modifier onlyGovernance() {
        require(msg.sender == governanceAddress, "Governance Restriction: Not allowed");
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
        governanceAddress = _governanceAddress;
    }
    
    
    function setAirdropAddress(address _airdropAddress) external onlyGovernance {
        require(_airdropAddress != address(0), "null address given");
        airdropAddress = _airdropAddress;
    
    }
    
    function setAPMAddress(address  _apmAddress) external onlyGovernance {
    require(_apmAddress != address(0), "not null address" );
    apmAddress = _apmAddress;
    }
    
    function setDebondData(address  _dataAddress) external onlyGovernance {
    require(_dataAddress != address(0), "not null address" );
    dataAddress = _dataAddress;
    }
    
    function setOracle (address  _newOracle) external onlyGovernance {
    require(_newOracle != address(0), "not null address" );
    dataAddress = _dataAddress;
    }
    
    function setDBITAddress(address _dbitAddress) external onlyGovernance {
    require(_dbitAddress != address(0), "not null address" );
    dbitAddress = _dbitAddress;
    }

    function  setDGOVAddress(address _dgovAddress) external onlyGovernance {
    require( _dgovAddress != address(0), "not null address" );
    dgovAddress =  _dgovAddress;
    }
}
