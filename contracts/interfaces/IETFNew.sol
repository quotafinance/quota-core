// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IETF {

    function getPriorBalance(address account, uint blockNumber) external view returns (uint256);
    function mintForReferral(address to, uint256 amount) external;
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function balanceOf(address who) external view returns (uint256);
}