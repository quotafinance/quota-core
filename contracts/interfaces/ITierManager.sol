//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

interface ITierManager {
    function checkTierUpgrade(uint256[] memory) external returns (bool);
    function getTransferLimit(uint256) external view returns (uint256);
    function getTokenURI(uint256) external view returns (string memory); 
}