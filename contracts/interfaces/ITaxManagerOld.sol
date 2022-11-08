// SPDX-License-Identifier: MIT
pragma solidity 0.5.16;

interface ITaxManager {
    function getSelfTaxPool() external returns (address);
    function getRightUpTaxPool() external view returns (address);
    function getSelfTaxRate() external returns (uint256);
    function getRightUpTaxRate() external view returns (uint256);
    function getProtocolTaxRate() external view returns (uint256);
    function getTotalTaxAtMint() external view returns (uint256);
    function getPerpetualPoolTaxRate() external view returns (uint256);
    function getTaxBaseDivisor() external view returns (uint256);
    function getReferralRate(uint256, uint256) external view returns (uint256);
    function getLeftOverPool() external view returns (address);
}

