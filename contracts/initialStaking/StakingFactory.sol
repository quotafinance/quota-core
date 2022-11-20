import "./EscrowToken.sol";
import "./TokenRewards.sol";

pragma solidity 0.5.16;

contract StakingFactory {

    address public token;
    address public nftFactory;
    address public notifier;
    address public owner;
    modifier onlyOwner() {
        require(msg.sender == owner, "caller is not the owner");
        _;
    }

    constructor(address _token, address _notifier, address _nftFactory) public {
        token = _token;
        nftFactory = _nftFactory;
        notifier = _notifier;
        owner = msg.sender;
    }

    function initialize (address lp, uint256 amount) public {
        address escrowToken = address(new EscrowToken(amount));
        address stakingPool = address(new TokenRewards(escrowToken, lp));
        IERC20(escrowToken).transfer(stakingPool, amount * 1e18);
        address poolEscrow = address(new PoolEscrow(escrowToken, stakingPool, token, owner, nftFactory));
        TokenRewards(stakingPool).setEscrow(poolEscrow);
        TokenRewards(stakingPool).setRewardDistribution(notifier);
        TokenRewards(stakingPool).transferOwnership(owner);
        PoolEscrow(poolEscrow).setGovernance(owner);
    }

}