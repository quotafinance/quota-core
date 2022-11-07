//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

contract TaxManager {

    address public selfTaxPool;
    address public rightUpTaxPool;
    address public maintenancePool;
    address public devPool;
    address public rewardAllocationPool;
    address public perpetualPool;
    address public admin;
    uint256 public selfTaxRate;
    uint256 public rightUpTaxRate;
    uint256 public maintenanceTaxRate;
    uint256 public protocolTaxRate;
    uint256 public perpetualPoolTaxRate;
    uint256 public taxBaseDivisor;
    uint256[][] public referralRate;

    modifier onlyAdmin() { // Change this to a list with ROLE library
        require(msg.sender == admin, "only admin");
        _;
    }


    function setSelfTaxPool(address _selfTaxPool) external {
        selfTaxPool = _selfTaxPool;
    }

    function getSelfTaxPool() external view returns (address) {
        return selfTaxPool;
    }

    function setRightUpTaxPool(address _rightUpTaxPool) external {
        rightUpTaxPool = _rightUpTaxPool;
    }

    function getRightUpTaxPool() external view returns (address) {
        return rightUpTaxPool;
    }

    function setMaintenancePool(address _maintenancePool) external {
        maintenancePool = _maintenancePool;
    }

    function getMaintenancePool() external view returns (address) {
        return maintenancePool;
    }

    function setDevPool(address _devPool) external {
        devPool = _devPool;
    }

    function getDevPool() external view returns (address) {
        return devPool;
    }

    function setRewardAllocationPool(address _rewardAllocationPool) external {
        rewardAllocationPool = _rewardAllocationPool;
    }

    function getRewardAllocationPool() external view returns (address) {
        return rewardAllocationPool;
    }

    function setPerpetualPool(address _perpetualPool) external {
        perpetualPool = _perpetualPool;
    }

    function getPerpetualPool() external view returns (address) {
        return perpetualPool;
    }

    function setSelfTaxRate(uint256 _selfTaxRate) external {
        selfTaxRate = _selfTaxRate;
    }

    function getSelfTaxRate() external view returns (uint256) {
        return selfTaxRate;
    }

    function setRightUpTaxRate(uint256 _rightUpTaxRate) external {
        rightUpTaxRate = _rightUpTaxRate;
    }

    function getRightUpTaxRate() external view returns (uint256) {
        return rightUpTaxRate;
    }

    function setMaintenanceTaxRate(uint256 _maintenanceTaxRate) external {
        maintenanceTaxRate = _maintenanceTaxRate;
    }

    function getMaintenanceTaxRate() external view returns (uint256) {
        return maintenanceTaxRate;
    }

    function setProtocolTaxRate(uint256 _protocolTaxRate) external {
        protocolTaxRate = _protocolTaxRate;
    }

    function getProtocolTaxRate() external view returns (uint256) {
        return protocolTaxRate;
    }

    function getTotalTaxAtMint() external view returns (uint256) {
        return protocolTaxRate + rightUpTaxRate + selfTaxRate;
    }

    function setPerpetualPoolTaxRate(uint256 _perpetualPoolTaxRate) external {
        perpetualPoolTaxRate = _perpetualPoolTaxRate;
    }

    function getPerpetualPoolTaxRate() external view returns (uint256) {
        return perpetualPoolTaxRate;
    }

    function setTaxBaseDivisor(uint256 _taxBaseDivisor) external {
        taxBaseDivisor = _taxBaseDivisor;
    }

    function getTaxBaseDivisor() external view returns (uint256) {
        return taxBaseDivisor;
    }

    function setReferralRate(uint256 depth, uint256 tier, uint256 _referralRate) external {
        referralRate[depth][tier] = _referralRate;
    }

    function setBulkReferralRate(uint256 tier, uint256[] memory rates) external {
        require(rates.length == 4, "Must have taxes for all 4 depths");
        for (uint256 i = 0; i < rates.length; i++) {
            referralRate[i+1][tier] = rates[i];
        }
    }

    function getReferralRate(uint256 depth, uint256 tier) external view returns (uint256) {
        return referralRate[depth][tier];
    }
}


