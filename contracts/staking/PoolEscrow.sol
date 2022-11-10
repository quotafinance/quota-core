pragma solidity ^0.5.0;

import "../openzeppelin/SafeMath.sol";
import "../openzeppelin/SafeERC20.sol";
import "./TokenRewards.sol";

contract PoolEscrow {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    modifier onlyGov() {
        require(msg.sender == governance, "only governance");
        _;
    }

    address public shareToken;
    address public pool;
    address public token;
    address public development;
    address public governancePool;
    address public dao;
    address public governance;
    uint256 public lastMint;

    constructor(address _shareToken,
        address _pool,
        address _token,
        address _development,
        address _governancePool,
        address _dao) public {
        shareToken = _shareToken;
        pool = _pool;
        token = _token;
        development = _development;
        governancePool = _governancePool;
        dao = _dao;
        governance = msg.sender;
        lastMint = block.timestamp + 3 hours;
    }

    function setDevelopment(address account) external onlyGov {
        development = account;
    }

    function setGovernancePool(address account) external onlyGov {
        governancePool = account;
    }

    function setDao(address account) external onlyGov {
        dao = account;
    }

    function setGovernance(address account) external onlyGov {
        governance = account;
    }

    function release(address recipient, uint256 shareAmount) external {
        require(msg.sender == pool, "only pool can release tokens");
        IERC20(shareToken).safeTransferFrom(msg.sender, address(this), shareAmount);
        uint256 endowment = getTokenNumber(shareAmount).mul(5).div(100);
        uint256 reward = getTokenNumber(shareAmount);
        if (development != address(0)) {
            IERC20(token).safeTransfer(development, endowment.mul(2));
            reward = reward.sub(endowment.mul(2));
        }
        if (governancePool != address(0)) {
            IERC20(token).safeTransfer(governancePool, endowment);
            reward = reward.sub(endowment);
        }
        if (dao != address(0)) {
            IERC20(token).safeTransfer(dao, endowment);
            reward = reward.sub(endowment);
        }
        IERC20(token).safeTransfer(recipient, reward);
        IERC20Burnable(shareToken).burn(shareAmount);
    }

    function getTokenNumber(uint256 shareAmount) public view returns(uint256) {
        return IERC20(token).balanceOf(address(this))
            .mul(shareAmount)
            .div(IERC20(shareToken).totalSupply());
    }

    /**
    * Functionality for secondary pool escrow. Transfers Rebasing tokens from msg.sender to this
    * escrow. At most per day, mints a fixed number of escrow tokens to the pool, and notifies
    * the pool. The period 1 day should match the secondary pool.
    */
    function notifySecondaryTokens(uint256 number) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), number);
        if (lastMint.add(14 days) < block.timestamp) {
            uint256 dailyMint = 1000000 * 1e18;
            IERC20Mintable(shareToken).mint(pool, dailyMint);
            TokenRewards(pool).notifyRewardAmount(dailyMint);
            lastMint = block.timestamp;
        }
    }
}



interface IERC20Burnable {
    function burn(uint256 amount) external;
}

interface IERC20Mintable {
    function mint(address to, uint256 amount) external;
}