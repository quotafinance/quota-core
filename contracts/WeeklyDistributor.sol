// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
import "./interfaces/IReferralHandler.sol";
import "./interfaces/IETFNew.sol";
import "./interfaces/INFTFactory.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WeeklyDistributor {
    using SafeMath for uint256;
    address public admin;
    uint256 public tier;
    address public manager;

    modifier onlyAdmin() {
        // Change this to a list with ROLE library
        require(msg.sender == admin, "only admin");
        _;
    }

    constructor(uint256 _tier, address _manager) {
        tier = _tier;
        manager = _manager;
        admin = msg.sender;
    }

    modifier onlyManager() {
        // Change this to a list with ROLE library
        require(msg.sender == manager, "only manager");
        _;
    }

    function setAdmin(address account) public onlyAdmin {
        admin = account;
    }

    function setManager(address account) public onlyAdmin {
        manager = account;
    }

    function distributeRewards() public onlyManager {
        address etf = IWeeklyDistributionManager(manager).getToken();
        uint256[] memory users = IWeeklyDistributionManager(manager).getUsers(
            tier
        );
        address factory = IWeeklyDistributionManager(manager).getFactory();
        uint256 totalUsers = users.length;
        uint256 totalReward = IERC20(etf).balanceOf(address(this));
        if(totalUsers > 0) {
            uint256 rewardPerUser = totalReward.div(totalUsers);
            for (uint i = 0; i < users.length; i++) {
                address depositBox = INFTFactory(factory).getDepositBox(users[i]);
                IETF(etf).transferForRewards(depositBox, rewardPerUser);
            }
        }
    }

    function recoverLeftover(
        address token,
        address benefactor
    ) public onlyAdmin {
        uint256 leftOverBalance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(benefactor, leftOverBalance);
    }
}

interface IWeeklyDistributionManager {
    function getToken() external view returns (address);

    function getFactory() external view returns (address);

    function getUsers(uint256 tier) external view returns (uint256[] memory);
}
