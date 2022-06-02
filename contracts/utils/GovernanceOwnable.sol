// SPDX-License-Identifier: apache 2.0

pragma solidity ^0.8.0;

import "../interfaces/IActivable.sol";
import "../interfaces/IGovernanceAddressUpdatable.sol";

contract GovernanceOwnable is IActivable, IGovernanceAddressUpdatable {
    address public dataAddress;
    address public dbit;
    address public dgov;

    address public exchangeAddress;
    address  governanceAddress;
    address public  bankAddress;
    address public dbitAddress;
    address public dgovAddress;
    address public stakingDGOV;
    address public voteToken;
    bool isActive;

    constructor(address _governanceAddress) {
        governanceAddress = _governanceAddress;
        isActive = true;
    }

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

    function setDBITTokenContract(address _newDBITAddress) external onlyGovernance {
        dbitAddress = _newDBITAddress;
    }
    function setDGOVTokenContract(address _newDGOVTokenAddress) external onlyGovernance {
        dbitAddress = _newDGOVTokenAddress;
    }
    
    function setBankAddress(address _newBankAddress) external onlyGovernance {
        bankAddress = _newBankAddress;
    }
    

    function setExchangeAddress(address _newExchangeAddress) external onlyGovernance {
        exchangeAddress = _newExchangeAddress;
    }


    /**
    * @dev set the stakingDGOV contract address
    * @param _stakingDGOV stakingDGOV contract address
    */
    function setStakingDGOVContract(address _stakingDGOV) external onlyGovernance {
        stakingDGOV = _stakingDGOV;
    }

    function setVoteTokenContract(address _newVoteToken) external onlyGovernance{

        voteToken = _newVoteToken;
        
    }

}
