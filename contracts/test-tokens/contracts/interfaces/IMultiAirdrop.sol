pragma solidity ^0.8.9;

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

// Based on the Uniswap Airdrop

interface IMultiAirdrop {
    // Returns the addresses of the tokens distributed by this contract.
    struct AirdropToken {
        address payable token;
        uint256 airdropped;
    }


    function tokens() external view returns (AirdropToken[] memory);

    // Returns the information of the token distributed by this contract.
    function totalAirdrop(address token) external view returns (uint256);

    // Returns the merkle root of the merkle tree containing account balances available to claim.
    function merkleRoot() external view returns (bytes32);

    // Returns true if the index has been marked claimed.
    function isClaimed(uint256 index) external view returns (bool);

    // Claim the given amount of the token to the given address. Reverts if the inputs are invalid.
    function claim(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external;

    // Prepare airdrop (define tokens and dropped amounts)
    function setAirDrop(bytes32 root, AirdropToken[] memory tokens_)
    external
    returns (bool);

    // Modify merkle root
    function setMerkleRoot(bytes32 root) external returns (bool);

    // This event is triggered whenever a call to #claim succeeds.
    event Claimed(uint256 index, address account, uint256 amount);
}