// SPDX-License-Identifier: apache 2.0

pragma solidity ^0.8.0;

import "../interfaces/IActivable.sol";
import "../interfaces/IGovernanceAddressUpdatable.sol";

contract GovernanceOwnable is IActivable, IGovernanceAddressUpdatable {
    address public dataAddress;
    constructor(address _governanceAddress) {
        governanceAddress = _governanceAddress;
        isActive = true;
    }

    address governanceAddress;
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

    function setDebondDataAddress(address _newDataAddress) external onlyGovernance {
        dataAddress = _newDataAddress;
    }

}
