pragma solidity ^0.8.9;

interface IAirdropContract {

    function setAirdrop(uint256 supply) external returns (bool);

    function isClaimed(uint256 index) external view returns (bool);

    function setMerkleRoot(bytes32 root) external returns (bool);

    function claim(
        uint256 index,
        address to,
        uint256 amount,
        bytes32[] calldata proof
    ) external;
}


