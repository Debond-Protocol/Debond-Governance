//
pragma solidity ^0.8.0;

import "../interfaces/IDebondToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


contract DBITAirdrop is Ownable {

    using ECDSA for bytes32;


    address dbitAddress;
    IDebondToken token;

    uint256 claimStart; // initial timestamp for starting the airdrop claim by the users
    uint256 claimDuration; // time taken (in sec) for the completion of the claim time

    bool public claim_started = false;
    bool public merkleRoot_set = false;
    bytes32 public merkleRoot; //airdrop_list_mercleRoof
    // checks whether the call is executed.
    mapping(address => bool) public withdrawClaimed;

    constructor(
        address DBITAddress,
        uint256 _claimStart,
        uint256 _claimDuration
    ) {
        dbitAddress = DBITAddress;
        token = IDebondToken(DBITAddress);
        claimStart = _claimStart;
        claimDuration = _claimDuration;
    }


    modifier isClaimedAuthorized(uint256 quantity, bytes memory signature) {
        require(verifySignature(quantity, signature) == owner(), "caller not authorized to get airdrop");
        _;
    }

    function claimAirdrop(uint256 _amount, bytes memory _signature) external isClaimedAuthorized(_amount, _signature) {
        require(claim_started == true, "initial claim time isnt passed.");
        require(!withdrawClaimed[msg.sender], "caller already got airdropped");
        token.mintAirdroppedSupply(msg.sender, _amount);
        withdrawClaimed[msg.sender] = true;
    }

    function verifySignature(uint256 quantity, bytes memory signature) internal view returns (address) {
        return keccak256(abi.encodePacked(address(this), msg.sender, quantity))
        .toEthSignedMessageHash()
        .recover(signature);
    }


    function startClaim() public view returns (bool) {
        require(msg.sender == owner(), "DBIT Credit Airdrop: Dev only.");
        require(block.timestamp >= claimDuration, "DBIT Credit Airdrop: too early.");
        require(
            claim_started == false,
            "DBIT Credit Airdrop: Claim already started."
        );
        require(
            merkleRoot_set == true,
            "DBIT Credit Airdrop: Merkle root invalid."
        );

        claim_started == true;
        return true;
    }
}
