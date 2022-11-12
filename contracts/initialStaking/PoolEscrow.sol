pragma solidity ^0.5.0;

import "../openzeppelin/SafeMath.sol";
import "../openzeppelin/SafeERC20.sol";
import "./TokenRewards.sol";
import "../interfaces/ITaxManagerOld.sol";
import "../interfaces/IETF.sol";

contract PoolEscrow {

    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    modifier onlyGov() {
        require(msg.sender == governance, "only governance");
        _;
    }

    address public shareToken;
    address public pool;
    IETF public token;
    ITaxManager public taxManager;
    address public distributor;
    address public governance;
    uint256 public lastMint;

    constructor(address _shareToken,
        address _pool,
        address _token,
        address _taxManager) public {
        shareToken = _shareToken;
        pool = _pool;
        token = IETF(_token);
        taxManager = ITaxManager(_taxManager);
        governance = msg.sender;
        lastMint = block.timestamp + 3 hours;
    }

    function setGovernance(address account) external onlyGov {
        governance = account;
    }

    function release(address recipient, uint256 shareAmount) external {
        require(msg.sender == pool, "only pool can release tokens");
        IERC20(shareToken).safeTransferFrom(msg.sender, address(this), shareAmount);
        uint256 reward = getTokenNumber(shareAmount);
        uint256 protocolTaxRate = taxManager.getProtocolTaxRate();
        uint256 taxDivisor = taxManager.getTaxBaseDivisor();
        uint256 totalTax = getTokenNumber(shareAmount).mul(protocolTaxRate).div(taxDivisor);
        // Check this part one more time
        distributeTax(reward, protocolTaxRate, taxDivisor);
        reward = reward.sub(totalTax);
        token.transfer(recipient, reward);
        IERC20Burnable(shareToken).burn(shareAmount);
    }

    function getTokenNumber(uint256 shareAmount) public view returns(uint256) {
        return token.balanceOf(address(this))
            .mul(shareAmount)
            .div(IERC20(shareToken).totalSupply());
    }

    /**
    * Functionality for secondary pool escrow. Transfers Rebasing tokens from msg.sender to this
    * escrow. It adds equal amount of escrow share token to the staking pool and notifies it to
    * extend reward period.
    */
    function notifySecondaryTokens(uint256 amount) external {
        token.transferFrom(msg.sender, address(this), amount);
        uint256 freshMint = amount;
        IERC20Mintable(shareToken).mint(pool, freshMint);
        TokenRewards(pool).notifyRewardAmount(freshMint);
    }

    function distributeTax(uint256 balance ,uint256 protocolTaxRate, uint256 taxDivisor) internal {
        uint256 leftOverTaxRate = protocolTaxRate;
        {
        uint256 tierPoolTaxRate = taxManager.getTierPoolRate();
        address tierPool = taxManager.getTierPool();
        uint256 tierAllocation = balance.mul(tierPoolTaxRate).div(taxDivisor);
        token.transfer(tierPool, tierAllocation);
        leftOverTaxRate = leftOverTaxRate.sub(tierPoolTaxRate);
        }
        // Staking Pool Allocation
        {
        uint256 perpetualTaxRate = taxManager.getPerpetualPoolTaxRate();
        address stakingPool = taxManager.getPerpetualPool();
        uint256 stakingAllocation = balance.mul(perpetualTaxRate).div(taxDivisor);
        token.transfer(stakingPool, stakingAllocation);
        leftOverTaxRate = leftOverTaxRate.sub(perpetualTaxRate);
        }
        // Protocol Maintenance Allocation
        {
        uint256 protocolMaintenanceRate = taxManager.getMaintenanceTaxRate();
        uint256 protocolMaintenanceAmount = balance.mul(protocolMaintenanceRate).div(taxDivisor);
        address maintenancePool = taxManager.getMaintenancePool();
        token.transfer(maintenancePool, protocolMaintenanceAmount);
        leftOverTaxRate = leftOverTaxRate.sub(protocolMaintenanceRate);
        }
        // Dev Allocation
        {
        uint256 devTaxRate = taxManager.getDevPoolRate();
        uint256 devPoolAmount = balance.mul(devTaxRate).div(taxDivisor);
        address devPool = taxManager.getDevPool();
        token.transfer(devPool, devPoolAmount);
        leftOverTaxRate = leftOverTaxRate.sub(devTaxRate);
        }
        // Reward Allocation
        {
        uint256 rewardTaxRate = taxManager.getRewardPoolRate();
        uint256 rewardPoolAmount = balance.mul(rewardTaxRate).div(taxDivisor);
        address rewardPool = taxManager.getRewardAllocationPool();
        token.transfer(rewardPool, rewardPoolAmount);
        leftOverTaxRate = leftOverTaxRate.sub(rewardTaxRate);
        }
        // Revenue Allocation
        {
        uint256 leftOverTax = balance.mul(leftOverTaxRate).div(taxDivisor);
        address revenuePool = taxManager.getRevenuePool();
        token.transfer(revenuePool, leftOverTax);
        }
    }
}


interface IERC20Burnable {
    function burn(uint256 amount) external;
}

interface IERC20Mintable {
    function mint(address to, uint256 amount) external;
}