// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../interfaces/ITaxManager.sol";
import "../../interfaces/INFTFactory.sol";
import "../../interfaces/IReferralHandler.sol";
import "../../interfaces/IETFNew.sol";

contract FixedPoolEscrow {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    modifier onlyGov() {
        require(msg.sender == governance, "only governance");
        _;
    }

    address public pool;
    address public token;
    address public factory;
    address public governance;

    event RewardClaimed(address indexed userNFT, uint256 amount, uint256 time);

    constructor(
        address _pool,
        address _token,
        address _factory) {
        pool = _pool;
        token = _token;
        factory = _factory;
        governance = msg.sender;
    }

    function setGovernance(address account) external onlyGov {
        governance = account;
    }

    function setFactory(address account) external onlyGov {
        factory = account;
    }

    function recoverLeftoverTokens(address _token, address benefactor) public onlyGov
    {
        uint256 leftOverBalance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(benefactor, leftOverBalance);
    }

    function disperseRewards(address recipient, uint256 shareAmount) external {
        require(msg.sender == pool, "only pool can release tokens");
        uint256 reward = shareAmount;
        ITaxManager taxManager = ITaxManager(INFTFactory(factory).getTaxManager());
        uint256 protocolTaxRate = taxManager.getProtocolTaxRate();
        uint256 taxDivisor = taxManager.getTaxBaseDivisor();
        distributeTaxAndReward(recipient, reward, protocolTaxRate, taxDivisor);
    }


    function distributeTaxAndReward(address owner, uint256 currentClaimable, uint256 protocolTaxRate, uint256 taxDivisor) internal {
        ITaxManager taxManager = ITaxManager(INFTFactory(factory).getTaxManager());
        uint256 leftOverTaxRate = protocolTaxRate;
        address handler = INFTFactory(factory).getHandlerForUser(owner);
        address [5] memory referral; // Used to store above referrals, saving variable space
        // User Distribution
        // Block Scoping to reduce local Variables spillage
        {
        uint256 taxedAmount = currentClaimable.mul(protocolTaxRate).div(taxDivisor);
        uint256 userReward = currentClaimable.sub(taxedAmount);
        IETF(token).transferForRewards(owner, userReward);
        emit RewardClaimed(owner, userReward, block.timestamp);
        }
        {
        uint256 perpetualTaxRate = taxManager.getPerpetualPoolTaxRate();
        leftOverTaxRate = leftOverTaxRate.sub(perpetualTaxRate);
        // Does not need to be split and re-injected since its a single pool, collected in Escrow for future release
        uint256 perpetualAmount = currentClaimable.mul(perpetualTaxRate).div(taxDivisor);
        address perpetualPool = taxManager.getPerpetualPool();
        // IERC20(token).safeApprove(perpetualPool, 0);
        // IERC20(token).safeApprove(perpetualPool, perpetualAmount);
        // PoolEscrow(perpetualPool).notifySecondaryTokens(perpetualAmount);
        IETF(token).transferForRewards(perpetualPool, perpetualAmount);
        }
        // Block Scoping to reduce local Variables spillage
        {
        uint256 protocolMaintenanceRate = taxManager.getMaintenanceTaxRate();
        uint256 protocolMaintenanceAmount = currentClaimable.mul(protocolMaintenanceRate).div(taxDivisor);
        address maintenancePool = taxManager.getMaintenancePool();
        IETF(token).transferForRewards(maintenancePool, protocolMaintenanceAmount);
        leftOverTaxRate = leftOverTaxRate.sub(protocolMaintenanceRate); // Minted above
        }
        // Transfer taxes to referrers
        if(handler != address(0))
        {
            referral[1]  = IReferralHandler(handler).referredBy();
            if(referral[1] != address(0)) {
                // Block Scoping to reduce local Variables spillage
                {
                // Rightup Reward
                uint256 rightUpRate = taxManager.getRightUpTaxRate();
                uint256 rightUpAmount = currentClaimable.mul(rightUpRate).div(taxDivisor);
                IETF(token).transferForRewards(referral[1], rightUpAmount);
                leftOverTaxRate = leftOverTaxRate.sub(rightUpRate);
                // Normal Referral Reward
                uint256 firstTier = IReferralHandler(referral[1]).getTier();
                uint256 firstRewardRate = taxManager.getReferralRate(1, firstTier);
                leftOverTaxRate = leftOverTaxRate.sub(firstRewardRate);
                uint256 firstReward = currentClaimable.mul(firstRewardRate).div(taxDivisor);
                IETF(token).transferForRewards(referral[1], firstReward);
                }
                referral[2] = IReferralHandler(referral[1]).referredBy();
                if(referral[2] != address(0)) {
                    // Block Scoping to reduce local Variables spillage
                    {
                    uint256 secondTier = IReferralHandler(referral[2]).getTier();
                    uint256 secondRewardRate = taxManager.getReferralRate(2, secondTier);
                    leftOverTaxRate = leftOverTaxRate.sub(secondRewardRate);
                    uint256 secondReward = currentClaimable.mul(secondRewardRate).div(taxDivisor);
                    IETF(token).transferForRewards(referral[2], secondReward);
                    }
                    referral[3] = IReferralHandler(referral[2]).referredBy();
                    if(referral[3] != address(0)) {
                    // Block Scoping to reduce local Variables spillage
                        {
                        uint256 thirdTier = IReferralHandler(referral[3]).getTier();
                        uint256 thirdRewardRate = taxManager.getReferralRate(3, thirdTier);
                        leftOverTaxRate = leftOverTaxRate.sub(thirdRewardRate);
                        uint256 thirdReward = currentClaimable.mul(thirdRewardRate).div(taxDivisor);
                        IETF(token).transferForRewards(referral[3], thirdReward);
                        }
                        referral[4] = IReferralHandler(referral[3]).referredBy();
                        if(referral[4] != address(0)) {
                            // Block Scoping to reduce local Variables spillage
                            {
                            uint256 fourthTier = IReferralHandler(referral[4]).getTier();
                            uint256 fourthRewardRate = taxManager.getReferralRate(4, fourthTier);
                            leftOverTaxRate = leftOverTaxRate.sub(fourthRewardRate);
                            uint256 fourthReward = currentClaimable.mul(fourthRewardRate).div(taxDivisor);
                            IETF(token).transferForRewards(referral[4], fourthReward);
                            }
                        }
                    }
                }
            }
        }
        // Reward Allocation
        {
        uint256 rewardTaxRate = taxManager.getRewardPoolRate();
        uint256 rewardPoolAmount = currentClaimable.mul(rewardTaxRate).div(taxDivisor);
        address rewardPool = taxManager.getRewardAllocationPool();
        IETF(token).transferForRewards(rewardPool, rewardPoolAmount);
        leftOverTaxRate = leftOverTaxRate.sub(rewardTaxRate);
        }
        // Dev Allocation & // Revenue Allocation
        {
        uint256 leftOverTax = currentClaimable.mul(leftOverTaxRate).div(taxDivisor);
        address devPool = taxManager.getDevPool();
        address revenuePool = taxManager.getRevenuePool();
        IETF(token).transferForRewards(devPool, leftOverTax.div(2));
        IETF(token).transferForRewards(revenuePool, leftOverTax.div(2));
        }
    }
}


interface IERC20Burnable {
    function burn(uint256 amount) external;
}

interface IERC20Mintable {
    function mint(address to, uint256 amount) external;
}
