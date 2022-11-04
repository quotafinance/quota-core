//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

interface ICrytical {
  function rebase(uint256 epoch, uint256 supplyDelta, bool positive) external;
  function mint(address to, uint256 amount) external;
  function balanceOf(address account) external view returns (uint256);
}
