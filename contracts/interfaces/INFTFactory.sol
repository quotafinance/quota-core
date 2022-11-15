//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

interface INFTFactory {
    function getHandler(uint256) external view returns (address);
    function alertLevel(uint256, uint256) external;
}