// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/ITaxManager.sol";
import "../interfaces/IRebaserNew.sol";
import "../interfaces/IETFNew.sol";
import "../interfaces/INFTFactory.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract PoolHandler {

    using SafeMath for uint256;
    address public admin;
    address public factory;
    IETF public token;
    IRebaser public rebaser;
    address public pool;
    uint256 constant BASE = 10000;
    uint256 claimedEpoch; // Contructor sets the latest positive Epoch, to keep count of future epochs that need to be claimed

    constructor(
        address _pool,
        address _admin,
        address _rebaser,
        uint256 _epoch,
        address _token,
        address _factory
    ) {
        pool = _pool;
        admin = _admin;
        claimedEpoch = _epoch;
        rebaser = IRebaser(_rebaser);
        token = IETF(_token);
        factory = _factory;
    }

    function transferTax() external {
        uint256 currentEpoch = rebaser.getPositiveEpochCount();
        if (claimedEpoch < currentEpoch) {
            uint256 rebaseRate = rebaser.getDeltaForPositiveEpoch(claimedEpoch.add(1)); // Check for next epoch
            claimedEpoch++;
            if(rebaseRate != 0) {
                uint256 blockForRebase = rebaser.getBlockForPositiveEpoch(claimedEpoch.add(1));
                uint256 balanceDuringRebase = token.getPriorBalance(address(this), blockForRebase);
                uint256 expectedBalance = balanceDuringRebase.mul(BASE.add(rebaseRate)).div(BASE);
                uint256 balanceToMint = expectedBalance.sub(balanceDuringRebase);
                distributeTax(balanceToMint);
            }
        }
    }

    function distributeTax(uint256 balance) internal {
        ITaxManager taxManager = ITaxManager(INFTFactory(factory).getTaxManager());
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
        // Minted already during rebase
        {
        uint256 perpetualTaxRate = taxManager.getPerpetualPoolTaxRate();
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
        // Revenue & Marketing Allocation
        {
        uint256 leftOverTax = balance.mul(leftOverTaxRate).div(taxDivisor);
        address revenuePool = taxManager.getRevenuePool();
        address marketingPool = taxManager.getMaintenancePool();
        token.mintForReferral(revenuePool, leftOverTax/2);
        token.mintForReferral(marketingPool, leftOverTax/2);
        }
    }
}