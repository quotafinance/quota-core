// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../interfaces/IMembershipNFT.sol";
import "../interfaces/IReferralHandler.sol";
import "./INFTFactoryTest.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract ReferralHandler {

    using SafeMath for uint256;
    address public admin;
    address public factory;
    IMembershipNFT public NFTContract;
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

    event SelfTaxRewarded(address indexed NFT, uint256 amount, uint256 timestamp);
    event RewardClaimed(address indexed NFT,uint256 amount,uint256 timestamp);

    constructor(
        address _admin,
        address _referredBy,
        address _nftAddress,
        uint256 _nftId
    ) {
        admin = _admin;
        factory = msg.sender;
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
        uint256 oldTier = getTier(); // For events
        tier = _tier.add(1); // Adding the default +1 offset stored in handlers
        updateReferrersAbove(tier);
        INFTFactory(factory).alertLevel(oldTier, getTier());
    }

    function levelUp() public {
    // Levelup without checks for testing
        uint256 oldTier = getTier(); // For events
        updateReferrersAbove(tier.add(1));
        tier = tier.add(1);
        string memory tokenURI = INFTFactory(factory).getTokenURI(getTier()); // In prod this is from tiermanager
        NFTContract.changeURI(nftID, tokenURI);
        INFTFactory(factory).alertLevel(oldTier, getTier());
    }
}