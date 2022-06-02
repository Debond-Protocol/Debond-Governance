pragma solidity ^0.8.9;

interface IdGOV {
    function allocatedSupply() external view returns (uint256);

    function AirdropedSupply() external view returns (uint256);

    function supplyCollateralised() external view returns(uint256);

    /**getting locked balance for the given address */
    function LockedBalance(address _of) external view returns (uint256 _lockedBalance);

    function directTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) external returns (bool);

    //function totalSupply() external view returns(uint256);

    function mintAirdropedSupply(address _to, uint256 _amount) external;

    function mintCollateralisedSupply(address _to, uint256 _amount) external;

    function mintAllocatedSupply(address _to, uint256 _amount) external;

    function airdroppedSupplyBalance(address _from) external returns (uint256);

    function allocatedSupplyBalance(address _from) external returns (uint256);

    function totalSupply() external returns(uint);

    /**
    only set by airdropToken (which is further called by airdrop contract) in order to set airdrop token supply
     */
    function setAirdroppedSupply(uint256 new_supply) external returns (bool);

    function transfer(
        address _to,
        uint256 _amount
    ) external returns (bool);


    function setMaximumSupply(uint maximumSupply) external;

}



