// pragma solidity ^0.8.9;
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// // SPDX-License-Identifier: apache 2.0
// /*
//   Copyright 2020 Sigmoid Foundation <info@SGM.finance>
//   Licensed under the Apache License, Version 2.0 (the "License");
//   you may not use this file except in compliance with the License.
//   You may obtain a copy of the License at
//   http://www.apache.org/licenses/LICENSE-2.0
//   Unless required by applicable law or agreed to in writing, software
//   distributed under the License is distributed on an "AS IS" BASIS,
//   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//   See the License for the specific language governing permissions and
//   limitations under the License.
// */

// interface IAirdropToken { 


//   function setAirdropedSupply(uint256 total_airdroped_supply)
//     external
//     returns (bool);

//   function getLockedBalance(address account) external returns (uint256);


//   function getLockTime() external view returns(uint256);

//   function mintAirdrop(address to, uint256 amount) external returns (bool);


//   function setAirdropContractAddress(address newAddr) external returns(bool);



//   function setdGOV(address _dGOVAddress) external returns (bool);


// }



pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IAirdropToken {

    function setAirdropContract(address dropContract) external returns (bool);

    function getAirdropedSupply() external view returns (uint256);

    function setAirdropedSupply(uint256 total_airdroped_supply)
    external
    returns (bool);


    function setLockTime(uint lockTime_) external;

    function getTotalAirdropSupply() external view returns (uint);

    function getAirdropContract() external view returns (address);


    function mintAirdrop(address account, uint256 amount) external returns (bool);

    function lockedBalance(address account) external returns (uint256);

    function checkLockedBalance(address account, uint256 amount) external returns (bool);

    function claim() external returns (uint);
}