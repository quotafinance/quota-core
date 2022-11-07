//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "./interfaces/IMembershipNFT.sol";
import "./interfaces/IReferralHandler.sol";
import "./interfaces/ITierManager.sol";
import "./interfaces/IRebaserNew.sol";
import "./interfaces/IETFNew.sol";
import "./interfaces/ITaxManager.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract ReferralHandler {

    using SafeMath for uint256;
    address public admin;
    address public factory;
    ITierManager public tierManager;
    ITaxManager public taxManager;
    IMembershipNFT public NFTContract;
    IRebaser public rebaser;
    IETF public token;
    uint256 public nftID;
    address public referredBy; // NFT address of the referrer's ID
    address[] public referrals;
    uint256 private tier = 1; // Default tier is 1 instead of 0, since solidity 0 can also mean non-existant, all tiers on contract are + 1
    // NFT addresses of those referred by this NFT and its subordinates
    bool private canLevel = true;
    uint256 claimedEpoch; // Contructor sets the latest positive Epoch, to keep count of future epochs that need to be claimed
    address[] public firstLevelAddress;
    address[] public secondLevelAddress;
    address[] public thirdLevelAddress;
    address[] public fourthLevelAddress;
    // Mapping of the above Address list and their corresponding NFT tiers
    mapping (address => uint256) public first_level;
    mapping (address => uint256) public second_level;
    mapping (address => uint256) public third_level;
    mapping (address => uint256) public fourth_level;

    modifier onlyAdmin() { // TODO: Change this to a list with ROLE library
        require(msg.sender == admin, "only admin");
        _;
    }

   modifier onlyOwner() { // TODO: Change this to a list with ROLE library
        require(msg.sender == ownedBy(), "only owner");
        _;
    }

    modifier onlyFactory() { // TODO: Change this to a list with ROLE library
        require(msg.sender == factory, "only factory");
        _;
    }

    constructor(
        address _admin,
        uint256 _epoch,
        address _rebaser,
        address _token,
        address _tierManager,
        address _taxManager,
        address _referredBy,
        address _nftAddress,
        uint256 _nftId
    ) {
        admin = _admin;
        claimedEpoch = _epoch;
        rebaser = IRebaser(_rebaser);
        token = IETF(_token);
        factory = msg.sender;
        tierManager = ITierManager(_tierManager);
        taxManager = ITaxManager(_taxManager);
        referredBy = _referredBy;
        NFTContract = IMembershipNFT(_nftAddress);
        nftID = _nftId;
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

    function changeEligibility(bool status) public onlyAdmin {
        canLevel = status;
    }

    function remainingClaims() public view returns (uint256) {
        uint256 currentEpoch = rebaser.getPositiveEpochCount();
        return currentEpoch.sub(claimedEpoch);
    }

    function getTransferLimit() public view returns(uint256)
    {
        return tierManager.getTransferLimit(getTier());
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

        require(depth > 4, "Invalid depth");
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
        uint256[] memory tierCounts = new uint256[](6); // Tiers can be 0 to 5
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
        require( _tier >= 0 && _tier <=5, "Invalid depth");
        tier = _tier.add(1); // Adding the default +1 offset stored in handlers
        updateReferrersAbove(tier);
    }

    function levelUp() public {

        if(getTier() < 4 &&  canLevel == true && tierManager.checkTierUpgrade(getTierCounts()) == true)
        {

            updateReferrersAbove(tier.add(1));
            tier = tier.add(1);
            string memory tokenURI = tierManager.getTokenURI(getTier());
            NFTContract.changeURI(nftID, tokenURI);
        }
    }

    function claimReward() public { // Can be called by anyone but rewards always goto owner of NFT
        address owner = ownedBy();
        uint256 currentEpoch = rebaser.getPositiveEpochCount();
        uint256 protocolTaxRate = taxManager.getProtocolTaxRate();
        uint256 taxDivisor = taxManager.getTaxBaseDivisor();
        if (claimedEpoch < currentEpoch) {
            uint256 rebaseRate = rebaser.getDeltaForPositiveEpoch(claimedEpoch.add(1)); // Check for next epoch
            claimedEpoch++;
            if(rebaseRate != 0) {
                uint256 blockForRebase = rebaser.getBlockForPositiveEpoch(claimedEpoch.add(1));
                uint256 balanceDuringRebase = token.getPriorBalance(owner, blockForRebase); // We deal only with underlying balances
                uint256 selfTaxRate = taxManager.getSelfTaxRate();
                handleSelfTax(owner, balanceDuringRebase, selfTaxRate, protocolTaxRate, taxDivisor);
                uint256 rightUpTaxRate = taxManager.getRightUpTaxRate();
                if(rightUpTaxRate != 0)
                    handleRightUpTax(owner, balanceDuringRebase, rightUpTaxRate, protocolTaxRate, taxDivisor);
                rewardReferrers(balanceDuringRebase, protocolTaxRate, taxDivisor);
            }
        }
        uint256 currentClaimable = token.balanceOf(address(this));
        handleClaimTaxAndDistribution(owner, currentClaimable, protocolTaxRate, taxDivisor);
        levelUp();
    }

    function handleSelfTax(address owner, uint256 balance, uint256 taxRate, uint256 protocolTaxRate, uint256 divisor) internal {
        uint256 taxedAmountReward = balance.mul(taxRate).div(divisor);
        uint256 protocolTaxed = taxedAmountReward.mul(protocolTaxRate).div(divisor);
        uint256 reward = taxedAmountReward.sub(protocolTaxed);
        token.mintForReferral(owner, reward);
        token.mintForReferral(taxManager.getSelfTaxPool(), protocolTaxed);
    }

    function handleRightUpTax(address owner, uint256 balance, uint256 taxRate, uint256 protocolTaxRate,  uint256 divisor) internal {
        uint256 taxedAmountReward = balance.mul(taxRate).div(divisor);
        uint256 protocolTaxed = taxedAmountReward.mul(protocolTaxRate).div(divisor);
        uint256 reward = taxedAmountReward.sub(protocolTaxed);
        token.mintForReferral(owner, reward);
        token.mintForReferral(taxManager.getRightUpTaxPool(), protocolTaxed);
    }

    function rewardReferrers(uint256 balanceDuringRebase, uint256 protocolTaxRate, uint256 taxDivisor) internal {
        address _handler = address(this);
        uint256 perpetualTaxRate = taxManager.getPerpetualPoolTaxRate();
        uint256 leftOverTaxRate = protocolTaxRate.sub(perpetualTaxRate); // Taxed on rebase
        uint256 protocolMaintenanceRate = taxManager.getMaintenanceTaxRate();
        address [] memory referral; // Used to store above referrals, saving variable space
        // Block Scoping to reduce local Variables spillage
        {
        uint256 protocolMaintenanceAmount = balanceDuringRebase.mul(protocolMaintenanceRate).div(taxDivisor);
        address maintenancePool = taxManager.getMaintenancePool();
        token.mintForReferral(maintenancePool, protocolMaintenanceAmount);
        }
        leftOverTaxRate = leftOverTaxRate.sub(protocolMaintenanceRate); // Minted above
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
        handleLeftOverTax(balanceDuringRebase, leftOverTaxRate, taxDivisor);
    }

    function handleLeftOverTax(uint256 balanceDuringRebase, uint256 leftOverTaxRate, uint256 taxDivisor) internal {
        uint256 leftOverTax = balanceDuringRebase.mul(leftOverTaxRate).div(taxDivisor);
        address devPool = taxManager.getDevPool();
        address rewardPool = taxManager.getRewardAllocationPool();
        token.mintForReferral(devPool, leftOverTax.div(2));
        token.mintForReferral(rewardPool, leftOverTax.div(2));
    }

    function handleClaimTaxAndDistribution(address owner, uint256 currentClaimable, uint256 protocolTaxRate, uint256 taxDivisor) internal {
        uint256 leftOverTaxRate = protocolTaxRate;
        // User Distribution
        // Block Scoping to reduce local Variables spillage    
        {        
        uint256 taxedAmount = currentClaimable.mul(protocolTaxRate).div(taxDivisor);
        uint256 userReward = currentClaimable.sub(taxedAmount);
        token.mintForReferral(owner, userReward);
        }
        // Staking pool allocation
        // Block Scoping to reduce local Variables spillage    
        {
        uint256 perpetualTaxRate = taxManager.getPerpetualPoolTaxRate();
        address stakingPool = taxManager.getPerpetualPool();
        uint256 stakingAllocation = currentClaimable.mul(perpetualTaxRate).div(taxDivisor);
        token.mintForReferral(stakingPool, stakingAllocation);
        leftOverTaxRate = leftOverTaxRate.sub(perpetualTaxRate);
        }
        // Protocol Maintenance Allocation
        // Block Scoping to reduce local Variables spillage    
        {
        uint256 protocolMaintenanceRate = taxManager.getMaintenanceTaxRate();
        uint256 protocolMaintenanceAmount = currentClaimable.mul(protocolMaintenanceRate).div(taxDivisor);
        address maintenancePool = taxManager.getMaintenancePool();
        token.mintForReferral(maintenancePool, protocolMaintenanceAmount);
        leftOverTaxRate = leftOverTaxRate.sub(protocolMaintenanceRate);
        }
        // Dev pool and Reward Allocation pool
        // Block Scoping to reduce local Variables spillage    
        {
        uint256 leftOverTax = currentClaimable.mul(leftOverTaxRate).div(taxDivisor);
        address devPool = taxManager.getDevPool();
        address rewardPool = taxManager.getRewardAllocationPool();
        token.mintForReferral(devPool, leftOverTax.div(2));
        token.mintForReferral(rewardPool, leftOverTax.div(2));
        }
    }
}
