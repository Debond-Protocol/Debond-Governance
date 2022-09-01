pragma solidity ^0.8.0;

// SPDX-License-Identifier: apache 2.0
/*
    Copyright 2020 Sigmoid Foundation <info@dGOV.finance>
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

interface IStaking {
    function stakeDgovToken(
        address _staker,
        uint256 _amount
    ) external;

    function unstakeDgovToken(
        address _staker,
        uint256 _stakingCounter
    ) external returns(uint256 amountDGOV, uint256 amountVote);

    function getStakedDGOVAmount(
        address _staker,
        uint256 _stakingCounter
    ) external view returns(uint256 _stakedAmount);

    function getAvailableVoteTokens(
        address _staker,
        uint256 _stakingCounter
    ) external view returns(uint256 _voteTokens);

    function setLastTimeInterestWithdraw(
        address _staker,
        uint256 _stakingCounter
    ) external;

    function calculateInterestEarned(
        address _staker,
        uint256 _stakingCounter,
        uint256 _interestRate
    ) external view returns(uint256 interest, uint256 duration);

    function getStartTimeDurationAndLastWithdrawTime(
        address _staker,
        uint256 _stakingCounter
    ) external view returns(uint256 startTime, uint256 duration, uint256 lastWithdrawTime);
}