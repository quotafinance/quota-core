import "./EscrowToken.sol";
import "./TokenRewards.sol";

pragma solidity 0.5.16;

contract StakingFactory {

    address public token;
    address public taxManager;
    INotifier public notifier;
    address public owner;
    modifier onlyOwner() {
        require(msg.sender == owner, "caller is not the owner");
        _;
    }

    address[] pools;

    constructor(address _token, INotifier _notifier, address _taxManager) public {
        token = _token;
        taxManager = _taxManager;
        notifier = _notifier;
        owner = msg.sender;
    }

    function initialize (address lp, uint256 amount) public {
        address escrowToken = address(new EscrowToken(amount));
        address stakingPool = address(new TokenRewards(escrowToken, lp));
        pools.push(stakingPool);
        IERC20(escrowToken).transfer(stakingPool, amount * 1e18);
        address poolEscrow = address(new PoolEscrow(escrowToken, stakingPool, token, taxManager));
        TokenRewards(stakingPool).setEscrow(poolEscrow);
        TokenRewards(stakingPool).setRewardDistribution(notifier);
        TokenRewards(stakingPool).transferOwnership(owner);
        PoolEscrow(poolEscrow).setGovernance(owner);
    }

    function getPools() public view returns(address[] memory) {
        return pools;
    }

}
