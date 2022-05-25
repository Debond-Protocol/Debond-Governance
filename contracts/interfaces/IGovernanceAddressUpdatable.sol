// SPDX-License-Identifier: apache 2.0

pragma solidity ^0.8.0;

interface IGovernanceAddressUpdatable {

    function setGovernanceAddress(address _governanceAddress) external;
}
