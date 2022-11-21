// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./interfaces/IMembershipNFT.sol";
import "./interfaces/IReferralHandler.sol";
import "./interfaces/ITierManager.sol";
import "./interfaces/IRebaserNew.sol";
import "./interfaces/IETFNew.sol";
import "./interfaces/ITaxManager.sol";
import "./interfaces/INFTFactory.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ReferralHandler {

    using SafeMath for uint256;
    address public admin;
    address public factory;
    IMembershipNFT public NFTContract;
    IETF public token;
    uint256 public nftID;
    uint256 public mintTime;
    address public referredBy; // NFT address of the referrer's ID
    address[] public referrals;
    address public depositBox;
    uint256 private tier;
    bool private canLevel;
    uint256 claimedEpoch; // Contructor sets the latest positive Epoch, to keep count of future epochs that need to be claimed
    // NFT addresses of those referred by this NFT and its subordinates
    address[] public firstLevelAddress;
    address[] public secondLevelAddress;
    address[] public thirdLevelAddress;
    address[] public fourthLevelAddress;
    uint256 public BASE;
    // Mapping of the above Address list and their corresponding NFT tiers
    mapping (address => uint256) public first_level;
    mapping (address => uint256) public second_level;
    mapping (address => uint256) public third_level;
    mapping (address => uint256) public fourth_level;

    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == ownedBy(), "only owner");
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "only factory");
        _;
    }

    function initialize(
        address _admin,
        uint256 _epoch,
        address _token,
        address _referredBy,
        address _nftAddress,
        uint256 _nftId
    ) public {
        admin = _admin;
        claimedEpoch = _epoch;
        token = IETF(_token);
        factory = msg.sender;
        referredBy = _referredBy;
        NFTContract = IMembershipNFT(_nftAddress);
        nftID = _nftId;
        mintTime = block.timestamp;
        tier = 1; // Default tier is 1 instead of 0, since solidity 0 can also mean non-existant, all tiers on contract are + 1
        canLevel = true;
        BASE = 10000;
    }

    function ownedBy() public view returns (address) { // Returns the Owner of the NFT coupled with this handler
        return NFTContract.ownerOf(nftID);
    }

    function coupledNFT() public view returns (uint256) { // Returns the address of the NFT coupled with this handler
        return nftID;
    }

    function getTier() public view returns (uint256) {
        return tier.sub(1);
    }

    function getRebaser() public view returns (IRebaser) {
        address rebaser = INFTFactory(factory).getRebaser() ;
        return IRebaser(rebaser);
    }

    function getTierManager() public view returns (ITierManager) {
        address tierManager = INFTFactory(factory).getTierManager() ;
        return ITierManager(tierManager);
    }

    function getTaxManager() public view returns (ITaxManager) {
        address taxManager = INFTFactory(factory).getTaxManager() ;
        return ITaxManager(taxManager);
    }

    function changeEligibility(bool status) public onlyAdmin {
        canLevel = status;
    }

    function remainingClaims() public view returns (uint256) {
        uint256 currentEpoch = getRebaser().getPositiveEpochCount();
        return currentEpoch.sub(claimedEpoch);
    }

    function getTransferLimit() public view returns(uint256)
    {
        return getTierManager().getTransferLimit(getTier());
    }

    function getDepositBox() public view returns (address) {
        return depositBox;
    }

    function setDepositBox(address _depositBox) external onlyFactory {
        depositBox = _depositBox;
    }

    function checkExistenceAndLevel(uint256 depth, address referred) view public returns (uint256) {
        // Checks for existence for the given address in the given depth of the tree
        // Returns 0 if it does not exist, else returns the NFT tier
        require(depth > 4 && depth < 1, "Invalid depth");
        require(referred != address(0), "Invalid referred address");
        if (depth == 1) {
            return first_level[referred];
        } else if (depth == 2) {
            return second_level[referred];
        } else if (depth == 3) {
            return third_level[referred];
        } else if (depth == 4) {
            return fourth_level[referred];
        }
        return 0;
    }

    function updateReferrersAbove(uint256 _tier) internal {
        address _handler = address(this);
        address first_ref = IReferralHandler(_handler).referredBy();
        if(first_ref != address(0)) {
            IReferralHandler(first_ref).updateReferralTree(1, _tier);
            address second_ref = IReferralHandler(first_ref).referredBy();
            if(second_ref != address(0)) {
                IReferralHandler(second_ref).updateReferralTree(2, _tier);
                address third_ref = IReferralHandler(second_ref).referredBy();
                if(third_ref != address(0)) {
                    IReferralHandler(third_ref).updateReferralTree(3, _tier);
                    address fourth_ref = IReferralHandler(third_ref).referredBy();
                    if(fourth_ref != address(0))
                        IReferralHandler(fourth_ref).updateReferralTree(4, _tier);
                }
            }
        }
    }

    function addToReferralTree(uint256 depth, address referred, uint256 NFTtier) public onlyFactory { // _referral address is address of the NFT handler not the new user
        require(depth <= 4, "Invalid depth");
        require(referred != address(0), "Invalid referred address");
        if (depth == 1) {
            firstLevelAddress.push(referred);
            first_level[referred] = NFTtier;
        } else if (depth == 2) {
            secondLevelAddress.push(referred);
            second_level[referred] = NFTtier;
        } else if (depth == 3) {
            thirdLevelAddress.push(referred);
            third_level[referred] = NFTtier;
        } else if (depth == 4) {
            fourthLevelAddress.push(referred);
            fourth_level[referred] = NFTtier;
        }
    }

    function updateReferralTree(uint256 depth, uint256 NFTtier) external {
        require(depth <= 4 && depth >= 1, "Invalid depth");
        require(msg.sender != address(0), "Invalid referred address");
        if (depth == 1) {
            require(first_level[msg.sender]!= 0, "Cannot update non-existant entry");
            first_level[msg.sender] = NFTtier;
        } else if (depth == 2) {
            require(second_level[msg.sender]!= 0, "Cannot update non-existant entry");
            second_level[msg.sender] = NFTtier;
        } else if (depth == 3) {
            require(third_level[msg.sender]!= 0, "Cannot update non-existant entry");
            third_level[msg.sender] = NFTtier;
        } else if (depth == 4) {
            require(fourth_level[msg.sender]!= 0, "Cannot update non-existant entry");
            fourth_level[msg.sender] = NFTtier;
        }
    }

    function getTierCounts() public view returns (uint256[] memory) { // returns count of Tiers 0 to 5 under the user
        uint256[] memory tierCounts = new uint256[](5); // Tiers can be 0 to 4 (Stored 1 to 5 in Handlers)
        for (uint256 index = 0; index < firstLevelAddress.length; index++) {
            address referral = firstLevelAddress[index];
            uint256 NFTtier = first_level[referral].sub(1); // Subtrating one to offset the default +1 due to solidity limitations
            tierCounts[NFTtier]++;
        }
        for (uint256 index = 0; index < secondLevelAddress.length; index++) {
            address referral = secondLevelAddress[index];
            uint256 NFTtier = second_level[referral].sub(1);
            tierCounts[NFTtier]++;
        }
        for (uint256 index = 0; index < thirdLevelAddress.length; index++) {
            address referral = thirdLevelAddress[index];
            uint256 NFTtier = third_level[referral].sub(1);
            tierCounts[NFTtier]++;
        }
        for (uint256 index = 0; index < fourthLevelAddress.length; index++) {
            address referral = fourthLevelAddress[index];
            uint256 NFTtier = fourth_level[referral].sub(1);
            tierCounts[NFTtier]++;
        }
        return tierCounts;
    }

    function setTier(uint256 _tier) public onlyAdmin {
        require( _tier >= 0 && _tier < 5, "Invalid depth");
        uint256 oldTier = getTier(); // For events
        tier = _tier.add(1); // Adding the default +1 offset stored in handlers
        updateReferrersAbove(tier);
        string memory tokenURI = getTierManager().getTokenURI(getTier());
        NFTContract.changeURI(nftID, tokenURI);
        INFTFactory(factory).alertLevel(oldTier, getTier());
    }

    function levelUp() public {
        if(getTier() < 4 &&  canLevel == true && getTierManager().checkTierUpgrade(getTierCounts()) == true)
        {
            uint256 oldTier = getTier(); // For events
            updateReferrersAbove(tier.add(1));
            tier = tier.add(1);
            string memory tokenURI = getTierManager().getTokenURI(getTier());
            NFTContract.changeURI(nftID, tokenURI);
            INFTFactory(factory).alertLevel(oldTier, getTier());
        }
    }

    function claimReward() public { // Can be called by anyone but rewards always goes to owner of NFT
        // This function mints the tokens that were deducted at rebase and disperses them
        // This also calls the claim function if there referral rewards from below available to claim
        address owner = ownedBy();
        ITaxManager taxManager =  getTaxManager();
        uint256 currentEpoch = getRebaser().getPositiveEpochCount();
        uint256 protocolTaxRate = taxManager.getProtocolTaxRate();
        uint256 taxDivisor = taxManager.getTaxBaseDivisor();
        if (claimedEpoch < currentEpoch) {
            uint256 rebaseRate = getRebaser().getDeltaForPositiveEpoch(claimedEpoch.add(1)); // Check for next epoch
            claimedEpoch++;
            if(rebaseRate != 0) {
                uint256 blockForRebase = getRebaser().getBlockForPositiveEpoch(claimedEpoch.add(1));
                uint256 balanceDuringRebase = token.getPriorBalance(owner, blockForRebase); // We deal only with underlying balances
                uint256 expectedBalance = balanceDuringRebase.mul(BASE.add(rebaseRate)).div(BASE);
                uint256 balanceToMint = expectedBalance.sub(balanceDuringRebase);
                handleSelfTax(owner, balanceToMint, protocolTaxRate, taxDivisor);
                uint256 rightUpTaxRate = taxManager.getRightUpTaxRate();
                if(rightUpTaxRate != 0)
                    handleRightUpTax(balanceToMint, rightUpTaxRate, protocolTaxRate, taxDivisor);
                rewardReferrers(balanceToMint, protocolTaxRate, taxDivisor);
            }
        }
        uint256 currentClaimable = token.balanceOf(address(this));
        if(currentClaimable > 0)
            handleClaimTaxAndDistribution(owner, currentClaimable, protocolTaxRate, taxDivisor);
        levelUp();
    }

    function handleSelfTax(address owner, uint256 balance, uint256 protocolTaxRate, uint256 divisor) internal {
        ITaxManager taxManager =  getTaxManager();
        uint256 selfTaxRate = taxManager.getSelfTaxRate();
        uint256 taxedAmountReward = balance.mul(selfTaxRate).div(divisor);
        uint256 protocolTaxed = taxedAmountReward.mul(protocolTaxRate).div(divisor);
        uint256 reward = taxedAmountReward.sub(protocolTaxed);
        token.mintForReferral(owner, reward);
        INFTFactory(factory).alertSelfTaxClaimed(reward, block.timestamp);
        token.mintForReferral(taxManager.getSelfTaxPool(), protocolTaxed);
    }

    function handleRightUpTax(uint256 balance, uint256 taxRate, uint256 protocolTaxRate,  uint256 divisor) internal {
        address _handler = address(this);
        ITaxManager taxManager =  getTaxManager();
        uint256 taxedAmountReward = balance.mul(taxRate).div(divisor);
        uint256 protocolTaxed = taxedAmountReward.mul(protocolTaxRate).div(divisor);
        uint256 reward = taxedAmountReward.sub(protocolTaxed);
        address referrer =  IReferralHandler(_handler).referredBy();
        token.mintForReferral(referrer, reward);
        token.mintForReferral(taxManager.getRightUpTaxPool(), protocolTaxed);
    }

    function rewardReferrers(uint256 balanceDuringRebase, uint256 protocolTaxRate, uint256 taxDivisor) internal {
        // This function mints the tokens and disperses them to referrers above
        ITaxManager taxManager =  getTaxManager();
        address _handler = address(this);
        uint256 perpetualTaxRate = taxManager.getPerpetualPoolTaxRate();
        uint256 leftOverTaxRate = protocolTaxRate.sub(perpetualTaxRate); // Taxed and minted on rebase
        uint256 protocolMaintenanceRate = taxManager.getMaintenanceTaxRate();
        address [] memory referral; // Used to store above referrals, saving variable space
        // Block Scoping to reduce local Variables spillage
        {
        uint256 protocolMaintenanceAmount = balanceDuringRebase.mul(protocolMaintenanceRate).div(taxDivisor);
        address maintenancePool = taxManager.getMaintenancePool();
        token.mintForReferral(maintenancePool, protocolMaintenanceAmount);
        leftOverTaxRate = leftOverTaxRate.sub(protocolMaintenanceRate);
        }
        referral[1]  = IReferralHandler(_handler).referredBy();
        if(referral[1] != address(0)) {
            // Block Scoping to reduce local Variables spillage
            {
            uint256 firstTier = IReferralHandler(referral[1]).getTier();
            uint256 firstRewardRate = taxManager.getReferralRate(1, firstTier);
            leftOverTaxRate = leftOverTaxRate.sub(firstRewardRate);
            uint256 firstReward = balanceDuringRebase.mul(firstRewardRate).div(taxDivisor);
            token.mintForReferral(referral[1], firstReward);
            }
            referral[2] = IReferralHandler(referral[1]).referredBy();
            if(referral[2] != address(0)) {
                // Block Scoping to reduce local Variables spillage
                {
                uint256 secondTier = IReferralHandler(referral[2]).getTier();
                uint256 secondRewardRate = taxManager.getReferralRate(2, secondTier);
                leftOverTaxRate = leftOverTaxRate.sub(secondRewardRate);
                uint256 secondReward = balanceDuringRebase.mul(secondRewardRate).div(taxDivisor);
                token.mintForReferral(referral[2], secondReward);
                }
                referral[3] = IReferralHandler(referral[2]).referredBy();
                if(referral[3] != address(0)) {
                // Block Scoping to reduce local Variables spillage
                    {
                    uint256 thirdTier = IReferralHandler(referral[3]).getTier();
                    uint256 thirdRewardRate = taxManager.getReferralRate(3, thirdTier);
                    leftOverTaxRate = leftOverTaxRate.sub(thirdRewardRate);
                    uint256 thirdReward = balanceDuringRebase.mul(thirdRewardRate).div(taxDivisor);
                    token.mintForReferral(referral[3], thirdReward);
                    }
                    referral[4] = IReferralHandler(referral[3]).referredBy();
                    if(referral[4] != address(0)) {
                        // Block Scoping to reduce local Variables spillage
                        {
                        uint256 fourthTier = IReferralHandler(referral[4]).getTier();
                        uint256 fourthRewardRate = taxManager.getReferralRate(4, fourthTier);
                        leftOverTaxRate = leftOverTaxRate.sub(fourthRewardRate);
                        uint256 fourthReward = balanceDuringRebase.mul(fourthRewardRate).div(taxDivisor);
                        token.mintForReferral(referral[4], fourthReward);
                        }
                    }
                }
            }
        }
        // Dev Allocation
        {
        uint256 devTaxRate = taxManager.getDevPoolRate();
        uint256 devPoolAmount = balanceDuringRebase.mul(devTaxRate).div(taxDivisor);
        address devPool = taxManager.getDevPool();
        token.mintForReferral(devPool, devPoolAmount);
        leftOverTaxRate = leftOverTaxRate.sub(devTaxRate);
        }
        // Reward Allocation
        {
        uint256 rewardTaxRate = taxManager.getRewardPoolRate();
        uint256 rewardPoolAmount = balanceDuringRebase.mul(rewardTaxRate).div(taxDivisor);
        address rewardPool = taxManager.getRewardAllocationPool();
        token.mintForReferral(rewardPool, rewardPoolAmount);
        leftOverTaxRate = leftOverTaxRate.sub(rewardTaxRate);
        }
        // Revenue Allocation
        {
        uint256 leftOverTax = balanceDuringRebase.mul(leftOverTaxRate).div(taxDivisor);
        address revenuePool = taxManager.getRevenuePool();
        token.mintForReferral(revenuePool, leftOverTax);
        }
    }

    function handleClaimTaxAndDistribution(address owner, uint256 currentClaimable, uint256 protocolTaxRate, uint256 taxDivisor) internal {
        ITaxManager taxManager =  getTaxManager();
        uint256 leftOverTaxRate = protocolTaxRate;
        address _handler = address(this);
        address [] memory referral; // Used to store above referrals, saving variable space
        // User Distribution
        // Block Scoping to reduce local Variables spillage
        {
        uint256 taxedAmount = currentClaimable.mul(protocolTaxRate).div(taxDivisor);
        uint256 userReward = currentClaimable.sub(taxedAmount);
        token.transferForRewards(owner, userReward);
        INFTFactory(factory).alertReferralClaimed(userReward, block.timestamp);
        }
        {
        uint256 perpetualTaxRate = taxManager.getPerpetualPoolTaxRate();
        uint256 perpetualAmount = currentClaimable.mul(perpetualTaxRate).div(taxDivisor);
        leftOverTaxRate = leftOverTaxRate.sub(perpetualTaxRate);
        address perpetualPool = taxManager.getPerpetualPool();
        token.transferForRewards(perpetualPool, perpetualAmount);
        }
        // Block Scoping to reduce local Variables spillage
        {
        uint256 protocolMaintenanceRate = taxManager.getMaintenanceTaxRate();
        uint256 protocolMaintenanceAmount = currentClaimable.mul(protocolMaintenanceRate).div(taxDivisor);
        address maintenancePool = taxManager.getMaintenancePool();
        token.transferForRewards(maintenancePool, protocolMaintenanceAmount);
        leftOverTaxRate = leftOverTaxRate.sub(protocolMaintenanceRate); // Minted above
        }
        referral[1]  = IReferralHandler(_handler).referredBy();
        if(referral[1] != address(0)) {
            // Block Scoping to reduce local Variables spillage
            {
            // Rightup Reward
            uint256 rightUpRate = taxManager.getRightUpTaxRate();
            uint256 rightUpAmount = currentClaimable.mul(rightUpRate).div(taxDivisor);
            token.transferForRewards(referral[1], rightUpAmount);
            leftOverTaxRate = leftOverTaxRate.sub(rightUpRate);
            // Normal Referral Reward
            uint256 firstTier = IReferralHandler(referral[1]).getTier();
            uint256 firstRewardRate = taxManager.getReferralRate(1, firstTier);
            leftOverTaxRate = leftOverTaxRate.sub(firstRewardRate);
            uint256 firstReward = currentClaimable.mul(firstRewardRate).div(taxDivisor);
            token.transferForRewards(referral[1], firstReward);
            }
            referral[2] = IReferralHandler(referral[1]).referredBy();
            if(referral[2] != address(0)) {
                // Block Scoping to reduce local Variables spillage
                {
                uint256 secondTier = IReferralHandler(referral[2]).getTier();
                uint256 secondRewardRate = taxManager.getReferralRate(2, secondTier);
                leftOverTaxRate = leftOverTaxRate.sub(secondRewardRate);
                uint256 secondReward = currentClaimable.mul(secondRewardRate).div(taxDivisor);
                token.transferForRewards(referral[2], secondReward);
                }
                referral[3] = IReferralHandler(referral[2]).referredBy();
                if(referral[3] != address(0)) {
                // Block Scoping to reduce local Variables spillage
                    {
                    uint256 thirdTier = IReferralHandler(referral[3]).getTier();
                    uint256 thirdRewardRate = taxManager.getReferralRate(3, thirdTier);
                    leftOverTaxRate = leftOverTaxRate.sub(thirdRewardRate);
                    uint256 thirdReward = currentClaimable.mul(thirdRewardRate).div(taxDivisor);
                    token.transferForRewards(referral[3], thirdReward);
                    }
                    referral[4] = IReferralHandler(referral[3]).referredBy();
                    if(referral[4] != address(0)) {
                        // Block Scoping to reduce local Variables spillage
                        {
                        uint256 fourthTier = IReferralHandler(referral[4]).getTier();
                        uint256 fourthRewardRate = taxManager.getReferralRate(4, fourthTier);
                        leftOverTaxRate = leftOverTaxRate.sub(fourthRewardRate);
                        uint256 fourthReward = currentClaimable.mul(fourthRewardRate).div(taxDivisor);
                        token.transferForRewards(referral[4], fourthReward);
                        }
                    }
                }
            }
        }
        // Dev Allocation
        {
        uint256 devTaxRate = taxManager.getDevPoolRate();
        uint256 devPoolAmount = currentClaimable.mul(devTaxRate).div(taxDivisor);
        address devPool = taxManager.getDevPool();
        token.transferForRewards(devPool, devPoolAmount);
        leftOverTaxRate = leftOverTaxRate.sub(devTaxRate);
        }
        // Reward Allocation
        {
        uint256 rewardTaxRate = taxManager.getRewardPoolRate();
        uint256 rewardPoolAmount = currentClaimable.mul(rewardTaxRate).div(taxDivisor);
        address rewardPool = taxManager.getRewardAllocationPool();
        token.transferForRewards(rewardPool, rewardPoolAmount);
        leftOverTaxRate = leftOverTaxRate.sub(rewardTaxRate);
        }
        // Revenue Allocation
        {
        uint256 leftOverTax = currentClaimable.mul(leftOverTaxRate).div(taxDivisor);
        address revenuePool = taxManager.getRevenuePool();
        token.transferForRewards(revenuePool, leftOverTax);
        }
    }
}
