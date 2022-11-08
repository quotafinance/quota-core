// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
import "./interfaces/IReferralHandler.sol";
import "./interfaces/ICrytical.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./interfaces/IStakingPool.sol";

contract TierManager {

    using SafeMath for uint256;

    struct TierParamaters {
        uint256 stakedTokens;
        uint256 stakedDuration;
        uint256 tierZero;
        uint256 tierOne;
        uint256 tierTwo;
        uint256 tierThree;
        uint256 tierFour;
        uint256 tierFive;
    }

    address public admin;
    IStakingPool public stakingPool;
    mapping(uint256 => TierParamaters) levelUpConditions;
    mapping(uint256 => uint256) transferLimits;
    string[] public tokenURI;

    modifier onlyAdmin() { // Change this to a list with ROLE library
        require(msg.sender == admin, "only admin");
        _;
    }

    constructor(address _admin) {
        admin = _admin;
    }

    function setStakingPool(address pool) public onlyAdmin {
        stakingPool = IStakingPool(pool);
    }

    function scaleUpTokens(uint256 amount) pure public returns(uint256) {
        uint256 scalingFactor = 10 ** 18;
        return amount.mul(scalingFactor);
    }

    function setConditions (
        uint256 tier, uint256 stakedTokens, uint256 stakedDuration,
        uint256 tierZero, uint256 tierOne, uint256 tierTwo,
        uint256 tierThree
    ) public onlyAdmin {
        levelUpConditions[tier].stakedTokens = stakedTokens;
        levelUpConditions[tier].stakedDuration = stakedDuration;
        levelUpConditions[tier].tierZero = tierZero;
        levelUpConditions[tier].tierOne = tierOne;
        levelUpConditions[tier].tierTwo = tierTwo;
        levelUpConditions[tier].tierThree = tierThree;
    }

    function validateUserTier(address owner, uint256 tier, uint256[] memory tierCounts) view public returns (bool) {
        // Check if user has valid requirements for the tier, if it returns true it means they have the requirement for the tier sent as parameter

        if(stakingPool.stakedTokens(owner) < levelUpConditions[tier].stakedTokens)
            return false;
        if(stakingPool.stakedDuration(owner) < levelUpConditions[tier].stakedDuration)
            return false;
        if(tierCounts[0] < levelUpConditions[tier].tierZero)
            return false;
        if(tierCounts[1] < levelUpConditions[tier].tierOne)
            return false;
        if(tierCounts[2] < levelUpConditions[tier].tierTwo)
            return false;
        if(tierCounts[3] < levelUpConditions[tier].tierThree)
            return false;
        return true;
    }

    function setTokenURI(uint256 tier, string memory _tokenURI) onlyAdmin public {
        tokenURI[tier] = _tokenURI;
    }

    function getTokenURI(uint256 tier) public view returns (string memory) {
        return tokenURI[tier];
    }

    function setTransferLimit(uint256 tier, uint256 limitPercent) public onlyAdmin {
        require(limitPercent <= 100, "Limit cannot be above 100");
        transferLimits[tier] = limitPercent;
    }

    function getTransferLimit(uint256 tier) public view returns (uint256) {
        return transferLimits[tier];
    }

    function checkTierUpgrade(uint256[] memory tierCounts) view public returns (bool) {
        address owner = IReferralHandler(msg.sender).ownedBy();
        uint256 newTier = IReferralHandler(msg.sender).getTier().add(1);
        return validateUserTier(owner, newTier, tierCounts); // If it returns true it means user is eligible for an upgrade in tier
    }
}