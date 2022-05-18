// SPDX-License-Identifier: apache 2.0


pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IActivable.sol";


abstract contract Pausable is Ownable {

    address bankAddress;
    address exchangeAddress;
    address debondBondAddress;
    address DBITAddress;
    address DGOVAddress;

    function setBankAddress(address _bankAddress) external onlyOwner {
        bankAddress = _bankAddress;
    }

    function setExchangeAddress(address _exchangeAddress) external onlyOwner {
        exchangeAddress = _exchangeAddress;
    }

    function setDebondBondAddress(address _debondBondAddress) external onlyOwner {
        debondBondAddress = _debondBondAddress;
    }

    function setDBITAddress(address _DBITAddress) external onlyOwner {
        DBITAddress = _DBITAddress;
    }

    function setDGOVAddress(address _DGOVAddress) external onlyOwner {
        DGOVAddress = _DGOVAddress;
    }

    function setDebondAddresses(
        address _bankAddress,
        address _exchangeAddress,
        address _debondBondAddress,
        address _DBITAddress,
        address _DGOVAddress
    ) external onlyOwner {
        bankAddress = _bankAddress;
        exchangeAddress = _exchangeAddress;
        debondBondAddress = _debondBondAddress;
        DBITAddress = _DBITAddress;
        DGOVAddress = _DGOVAddress;
    }

    function setIsActiveAll(bool isActive) external onlyOwner {
        IActivable(bankAddress).setIsActive(isActive);
        IActivable(exchangeAddress).setIsActive(isActive);
        IActivable(debondBondAddress).setIsActive(isActive);
        IActivable(DBITAddress).setIsActive(isActive);
        IActivable(DGOVAddress).setIsActive(isActive);
    }
}
