// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface ITokenRewards {

    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function unlocksAt(address account) external view returns (uint256);
    function latestLockDuration(address account) external view returns (uint256);
    function uni() external view returns(address);
}