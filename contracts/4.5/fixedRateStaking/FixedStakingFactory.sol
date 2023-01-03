// SPDX-License-Identifier: MIT
import "./FixedPoolEscrow.sol";
import "./FixedTokenRewarder.sol";

pragma solidity 0.8.4;

contract FixedStakingFactory {

    address public token;
    address public nftFactory;
    address public owner;
    modifier onlyOwner() {
        require(msg.sender == owner, "caller is not the owner");
        _;
    }

    address[] pools;
    address[] escrows;

    constructor(address _token, address _nftFactory) {
        token = _token;
        nftFactory = _nftFactory;
        owner = msg.sender;
    }

    function initialize() public {
        address stakingPool = address(new FixedTokenRewarder(token));
        pools.push(stakingPool);
        address poolEscrow = address(new FixedPoolEscrow(stakingPool, token, nftFactory));
        escrows.push(poolEscrow);
        FixedTokenRewarder(stakingPool).setEscrow(poolEscrow);
        FixedTokenRewarder(stakingPool).setRate(36500); // 365% a year, 1% per day
        FixedTokenRewarder(stakingPool).setAdmin(owner);
        FixedPoolEscrow(poolEscrow).setGovernance(owner);
    }

    function getPools() public view returns(address[] memory) {
        return pools;
    }

    function getEscrows() public view returns(address[] memory) {
        return escrows;
    }

}
