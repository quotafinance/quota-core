import "./EscrowToken.sol";
import "./TokenRewards.sol";

pragma solidity 0.5.16;

contract StakingFactory {

    address public token;
    address public dev;
    address public dao;
    address public gov;
    address public notifier;
    address public owner;
    modifier onlyOwner() {
        require(msg.sender == owner, "caller is not the owner");
        _;
    }

    constructor(address _token, address _notifier, address _dev, address _dao, address _gov) public {
        token = _token;
        dev = _dev;
        dao = _dao;
        gov = _gov;
        notifier = _notifier;
        owner = msg.sender;
    }

    function initialize (address lp) public {
        address escrowToken = address(new EscrowToken());
        address stakingPool = address(new TokenRewards(escrowToken, lp));
        IERC20(escrowToken).transfer(stakingPool, 30000000 * 1e18);
        address poolEscrow = address(new PoolEscrow(escrowToken, stakingPool, token, dev, gov, dao));
        TokenRewards(stakingPool).setEscrow(poolEscrow);
        TokenRewards(stakingPool).setRewardDistribution(notifier);
        TokenRewards(stakingPool).transferOwnership(owner);
        PoolEscrow(poolEscrow).setGovernance(owner);
    }

}