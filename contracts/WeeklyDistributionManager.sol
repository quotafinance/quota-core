// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
import "./interfaces/IETFNew.sol";
import "./interfaces/IMembershipNFT.sol";
import "./interfaces/ITokenRewards.sol";
import "./interfaces/INFTFactory.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WeeklyDistributionManager {
    using SafeMath for uint256;
    address public admin;
    address public etf;
    uint256[] public firstTierIDs;
    uint256[] public secondTierIDs;
    uint256[] public thirdTierIDs;
    uint256[] public fourthTierIDs;
    bool public usersFiltered = false;
    address[] public pools;
    address[] public distributors;
    address public nftAddress;
    address public factory;
    uint256 public nextRewardEpoch = 0;
    uint256 public rewardFrequency = 7 days;

    modifier onlyAdmin() { // Change this to a list with ROLE library
        require(msg.sender == admin, "only admin");
        _;
    }

    constructor( address _etf, address _nftAddress, address _factory) {
        admin = msg.sender;
        etf = _etf;
        nftAddress = _nftAddress;
        factory = _factory;
    }

    function getPools() public view returns(address[] memory) {
        return pools;
    }

    function getUsers(uint256 tier) public view returns(uint256[] memory) {
        if (tier == 1) {
            return firstTierIDs;
        } else if (tier == 2) {
            return secondTierIDs;
        } else if (tier == 3) {
            return thirdTierIDs;
        } else if (tier == 4) {
            return fourthTierIDs;
        }
        else
            return (new uint256[](0));
    }

    function getToken() public view returns (address) {
        return etf;
    }

    function getFactory() public view returns (address) {
        return factory;
    }

    function setAdmin(address account) public onlyAdmin {
        admin = account;
    }

    function setNFT(address account) public onlyAdmin {
        nftAddress = account;
    }

    function setFactory(address account) public onlyAdmin {
        factory = account;
    }

    function setNextReward(uint256 time) public onlyAdmin {
        nextRewardEpoch = time;
    }

    function addDistributors(address[] memory _distributors) onlyAdmin public {
        for (uint256 i = 0; i < _distributors.length; i++) {
            distributors.push(_distributors[i]);
        }
    }

    function removeDistributorsByIndex(uint256 index) onlyAdmin public returns(address) {
        require(index < distributors.length);
        for (uint i = index; i<distributors.length-1; i++){
            distributors[i] = distributors[i+1];
        }
        address removedDistributor = distributors[distributors.length-1];
        distributors.pop();
        return removedDistributor;
    }

    function addPools(address[] memory _pools) onlyAdmin public {
        for (uint256 i = 0; i < _pools.length; i++) {
            pools.push(_pools[i]);
        }
    }

    function removePoolByIndex(uint256 index) onlyAdmin public returns(address) {
        require(index < pools.length);
        for (uint i = index; i<pools.length-1; i++){
            pools[i] = pools[i+1];
        }
        address removedPool = pools[pools.length-1];
        pools.pop();
        return removedPool;
    }

    function filterAndStoreUsers(uint256 startBatch, uint256 endBatch) public onlyAdmin {
        for (uint i = startBatch; i <= endBatch; i++) {
            uint256 userTier = IMembershipNFT(nftAddress).tier(i);
            address userAddress = IMembershipNFT(nftAddress).ownerOf(i);
            if(checkIfUserIsStaking(userAddress)) {
                addUserToList(userTier, i);
            }
        }
        usersFiltered = true;
    }

    function distributeRewards() public onlyAdmin {
        if(block.timestamp >= nextRewardEpoch) {
            nextRewardEpoch = nextRewardEpoch.add(rewardFrequency);
            require(distributors.length == 4, "There can only be 4 distributors");
            require(usersFiltered == true, "Need to filter users before distribution");
            for (uint i = 0; i < distributors.length; i++) {
                IWeeklyDistributor(distributors[i]).distributeRewards();
            }
        }
    }

    function addUserToList(uint256 tier, uint256 userId) internal {
        if (tier == 1) {
            firstTierIDs.push(userId);
        } else if (tier == 2) {
            secondTierIDs.push(userId);
        } else if (tier == 3) {
            thirdTierIDs.push(userId);
        } else if (tier == 4) {
            fourthTierIDs.push(userId);
        }
    }

    function resetUserList() public onlyAdmin {
        delete firstTierIDs;
        delete secondTierIDs;
        delete thirdTierIDs;
        delete fourthTierIDs;
        usersFiltered = false;
    }


    function checkIfUserIsStaking(address user) public view returns (bool) {
        for (uint i = 0; i < pools.length; i++) {
            if(ITokenRewards(pools[i]).balanceOf(user) > 0)
                return true;
        }
        return false;
    }

    function recoverLeftover(address token, address benefactor) public onlyAdmin {
        uint256 leftOverBalance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(benefactor, leftOverBalance);
    }
}

interface IWeeklyDistributor {
    function distributeRewards() external;
}