// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/ITaxManager.sol";
import "../interfaces/IRebaserNew.sol";
import "../interfaces/IETFNew.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract PoolHandler {

    using SafeMath for uint256;
    address public admin;
    address public factory;
    IETF public token;
    ITaxManager public taxManager;
    IRebaser public rebaser;
    address public pool;
    uint256 claimedEpoch; // Contructor sets the latest positive Epoch, to keep count of future epochs that need to be claimed

    constructor(
        address _pool,
        address _admin,
        address _rebaser,
        uint256 _epoch,
        address _token,
        address _taxManager
    ) {
        pool = _pool;
        admin = _admin;
        claimedEpoch = _epoch;
        rebaser = IRebaser(_rebaser);
        token = IETF(_token);
        factory = msg.sender;
        taxManager = ITaxManager(_taxManager);
    }

    function transferTax() external {
        uint256 currentEpoch = rebaser.getPositiveEpochCount();
        if (claimedEpoch < currentEpoch) {
            uint256 rebaseRate = rebaser.getDeltaForPositiveEpoch(claimedEpoch.add(1)); // Check for next epoch
            claimedEpoch++;
            if(rebaseRate != 0) {
                uint256 blockForRebase = rebaser.getBlockForPositiveEpoch(claimedEpoch.add(1));
                uint256 balanceDuringRebase = token.getPriorBalance(address(this), blockForRebase);
                distributeTax(balanceDuringRebase);
            }
        }
    }

    function distributeTax(uint256 balance) internal {
        uint256 leftOverTaxRate = taxManager.getProtocolTaxRate();
        uint256 taxDivisor = taxManager.getTaxBaseDivisor();
        // Tier Rewards Allocation
        {
        uint256 tierPoolTaxRate = taxManager.getTierPoolRate();
        address tierPool = taxManager.getTierPool();
        uint256 tierAllocation = balance.mul(tierPoolTaxRate).div(taxDivisor);
        token.mintForReferral(tierPool, tierAllocation);
        leftOverTaxRate = leftOverTaxRate.sub(tierPoolTaxRate);
        }
        // Staking Pool Allocation
        {
        uint256 perpetualTaxRate = taxManager.getPerpetualPoolTaxRate();
        address stakingPool = taxManager.getPerpetualPool();
        uint256 stakingAllocation = balance.mul(perpetualTaxRate).div(taxDivisor);
        token.mintForReferral(stakingPool, stakingAllocation);
        leftOverTaxRate = leftOverTaxRate.sub(perpetualTaxRate);
        }
        // Protocol Maintenance Allocation
        {
        uint256 protocolMaintenanceRate = taxManager.getMaintenanceTaxRate();
        uint256 protocolMaintenanceAmount = balance.mul(protocolMaintenanceRate).div(taxDivisor);
        address maintenancePool = taxManager.getMaintenancePool();
        token.mintForReferral(maintenancePool, protocolMaintenanceAmount);
        leftOverTaxRate = leftOverTaxRate.sub(protocolMaintenanceRate);
        }
        // Dev Allocation
        {
        uint256 devTaxRate = taxManager.getDevPoolRate();
        uint256 devPoolAmount = balance.mul(devTaxRate).div(taxDivisor);
        address devPool = taxManager.getDevPool();
        token.mintForReferral(devPool, devPoolAmount);
        leftOverTaxRate = leftOverTaxRate.sub(devTaxRate);
        }
        // Reward Allocation
        {
        uint256 rewardTaxRate = taxManager.getRewardPoolRate();
        uint256 rewardPoolAmount = balance.mul(rewardTaxRate).div(taxDivisor);
        address rewardPool = taxManager.getRewardAllocationPool();
        token.mintForReferral(rewardPool, rewardPoolAmount);
        leftOverTaxRate = leftOverTaxRate.sub(rewardTaxRate);
        }
        // Revenue Allocation
        {
        uint256 leftOverTax = balance.mul(leftOverTaxRate).div(taxDivisor);
        address revenuePool = taxManager.getRevenuePool();
        token.transferForRewards(revenuePool, leftOverTax);
        }
    }
}