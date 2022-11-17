//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

interface INFTFactory {
    function getHandler(uint256) external view returns (address);
    function alertLevel(uint256, uint256) external;
    function alertSelfTaxClaimed(uint256, uint256) external;
    function alertReferralClaimed(uint256, uint256) external;
    function getTierManager() external view returns(address);
    function getTaxManager() external view returns(address);
    function getRebaser() external view returns(address);

}

// rebaser, , tierManager, taxManager,
