// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IAPYOracle {
  function tokenPerLP(address, address) external view returns (uint256);
}