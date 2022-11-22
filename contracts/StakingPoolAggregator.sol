// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./interfaces/IAPYOracle.sol";
import "./interfaces/ITokenRewards.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract StakingPoolAggregator {

    using SafeMath for uint256;
    address[] public pools;
    address public admin;
    address public oracle;
    address public token;

    constructor(address _token) {
        admin = msg.sender;
        token = _token;
    }


    modifier onlyAdmin() { // Change this to a list with ROLE library
        require(msg.sender == admin, "only admin");
        _;
    }

    function setAPYOracle(address _oracle) onlyAdmin public {
        oracle = _oracle;
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

    function checkForStakedRequirements(address user, uint256 stakedRequirement, uint256 stakedDuration) external view returns (bool) {
        uint256 totalStaked = 0;
        for (uint i = 0; i < pools.length; i++) {
            uint256 lpStaked = getStakedLPForDuration(pools[i], user, stakedDuration);
            //uint256 tokenRatio = IAPYOracle(oracle).tokenPerLP(pools[i], token);
            uint256 scaledTokens = lpStaked; //(lpStaked.mul(tokenRatio)).div(1e18);
            totalStaked = totalStaked.add(scaledTokens);
        }
        if(stakedRequirement <= totalStaked)
            return true;
        return false;
    }

    function getStakedLPForDuration(address pool, address user, uint256 stakedDuration) public view returns (uint256) {
        if(stakedDuration <= ITokenRewards(pool).latestLockDuration(user)) {
            return ITokenRewards(pool).balanceOf(user);
        }
        return 0; // Returns 0 incase the lockup duration is lower than required
    }
}