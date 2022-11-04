//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

interface IStakingPool {
    function stakedTokens(address account) external view returns (uint256);
    function stakedDuration(address account) external view returns (uint256);
}