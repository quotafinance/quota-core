import "./EscrowToken.sol";
import "./TokenRewards.sol";

pragma solidity 0.5.16;

contract StakingFactory {

    address public token;
    address public nftFactory;
    INotifier public notifier;
    address public owner;
    modifier onlyOwner() {
        require(msg.sender == owner, "caller is not the owner");
        _;
    }

    address[] pools;

    constructor(address _token, INotifier _notifier, address _nftFactory) public {
        token = _token;
        nftFactory = _nftFactory;
        notifier = _notifier;
        owner = msg.sender;
    }

    function setOwner(address account) public onlyOwner {
        owner = account;
    }

    function initialize (address lp, uint256 amount) public onlyOwner {
        address escrowToken = address(new EscrowToken(amount));
        address stakingPool = address(new TokenRewards(escrowToken, lp));
        pools.push(stakingPool);
        IERC20(escrowToken).transfer(stakingPool, amount);
        address poolEscrow = address(new PoolEscrow(escrowToken, stakingPool, token, nftFactory));
        TokenRewards(stakingPool).setEscrow(poolEscrow);
        TokenRewards(stakingPool).setRewardDistribution(notifier);
        TokenRewards(stakingPool).transferOwnership(owner);
        PoolEscrow(poolEscrow).setGovernance(owner);
    }

    function getPools() public view returns(address[] memory) {
        return pools;
    }

    function recoverTokens(
        address _token,
        address benefactor
    ) public onlyOwner {
        uint256 tokenBalance = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(benefactor, tokenBalance);
    }

}
