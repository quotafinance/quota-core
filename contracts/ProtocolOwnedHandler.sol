// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./interfaces/ITaxManager.sol";
import "./interfaces/IRebaserNew.sol";
import "./interfaces/IETFNew.sol";
import "./interfaces/INFTFactory.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
contract ProtocolOwnedHandler {

    using SafeMath for uint256;
    address public admin;
    address public factory;
    IETF public token;
    IRebaser public rebaser;
    address public pool;
    uint256 constant BASE = 1e18;
    uint256 public claimedEpoch; // Contructor sets the latest positive Epoch, to keep count of future epochs that need to be claimed
    address public protocolPool;

    constructor(
        address _pool,
        address _rebaser,
        uint256 _epoch,
        address _token,
        address _factory,
        address _protocolPool
    ) {
        pool = _pool;
        claimedEpoch = _epoch;
        rebaser = IRebaser(_rebaser);
        token = IETF(_token);
        factory = _factory;
        protocolPool = _protocolPool;
        admin = msg.sender;
    }

    modifier onlyAdmin() { // Change this to a list with ROLE library
        require(msg.sender == admin, "only admin");
        _;
    }

    function setPool(address _pool) public onlyAdmin {
        protocolPool = _pool;
    }

    function transferTax() external {
        uint256 currentEpoch = rebaser.getPositiveEpochCount();
        if (claimedEpoch < currentEpoch) {
            claimedEpoch++;
            uint256 rebaseRate = rebaser.getDeltaForPositiveEpoch(claimedEpoch);
            if(rebaseRate != 0) {
                uint256 blockForRebase = rebaser.getBlockForPositiveEpoch(claimedEpoch);
                uint256 balanceDuringRebase = token.getPriorBalance(address(pool), blockForRebase); // We deal only with underlying balances
                balanceDuringRebase = balanceDuringRebase.div(1e6); // 4.0 token internally stores 1e24 not 1e18
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
        // Staking Pool Allocation
        // Minted already during rebase
        {
        uint256 perpetualTaxRate = taxManager.getPerpetualPoolTaxRate();
        leftOverTaxRate = leftOverTaxRate.sub(perpetualTaxRate);
        }
        // Revenue Pool
        {
        address revenuePool = taxManager.getRevenuePool();
        uint256 revenuePoolAmount = balance.mul(150).div(taxDivisor); // 1.5%
        token.mintForReferral(revenuePool, revenuePoolAmount);
        leftOverTaxRate = leftOverTaxRate.sub(150);
        }
        // Reward Allocation
        {
        uint256 rewardTaxRate = taxManager.getRewardPoolRate();
        uint256 rewardPoolAmount = balance.mul(rewardTaxRate).div(taxDivisor);
        address rewardPool = taxManager.getRewardAllocationPool();
        token.mintForReferral(rewardPool, rewardPoolAmount);
        leftOverTaxRate = leftOverTaxRate.sub(rewardTaxRate);
        }
        // Maintenance Allocation
        {
        uint256 protocolMaintenanceRate = taxManager.getMaintenanceTaxRate();
        uint256 protocolMaintenanceAmount = balance.mul(protocolMaintenanceRate).div(taxDivisor);
        address maintenancePool = taxManager.getMaintenancePool();
        token.mintForReferral(maintenancePool, protocolMaintenanceAmount);
        leftOverTaxRate = leftOverTaxRate.sub(protocolMaintenanceRate);
        }
        // Protocol Allocation
        {
        uint256 leftOverTax = balance.mul(leftOverTaxRate).div(taxDivisor);
        token.mintForReferral(protocolPool, leftOverTax);
        }
    }
}