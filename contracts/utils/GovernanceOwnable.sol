// SPDX-License-Identifier: apache 2.0

pragma solidity ^0.8.0;

import "../interfaces/IActivable.sol";

contract GovernanceOwnable is IActivable {

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

    function setIsActive(bool _isActive) external virtual onlyGovernance {
        isActive = _isActive;
    }
}
