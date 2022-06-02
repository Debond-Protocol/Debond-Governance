pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// SPDX-License-Identifier: apache 2.0
/*
    Copyright 2020 Sigmoid Foundation <info@SGM.finance>
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
*/

interface IDebondToken {
    function mintCollateralisedSupply(address _to, uint256 _amount) external;

    function mintAllocatedSupply(address _to, uint256 _amount) external;

    function mintAirdroppedSupply(address _to, uint256 _amount) external;


    function supplyCollateralised() external returns (uint256);


    function collateralisedSupplyBalance(address _from) external returns (uint256);
   
    function airdroppedSupplyBalance(address _from) external returns (uint256);
   
    function allocatedSupplyBalance(address _from) external returns (uint256);
 

    function directTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) external returns (bool);

    function setAirdroppedSupply(uint256 new_supply) external returns (bool);

    function totalSupply() external view returns (uint256);

    function transfer(
        address _to,
        uint256 _amount
    ) external returns (bool);
}