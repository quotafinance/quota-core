// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract FixedTokenRewarder {

    using SafeMath for uint256;
    IERC20 public token;
    address public admin;
    address public escrow;
    uint256 public yearlyRate;
    mapping(address => uint256) public staked;
    mapping(address => uint256) private stakedFromTS;
    mapping(address => uint256) private unclaimedRewards;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin");
        _;
    }

    constructor(address _token) {
        token = IERC20(_token);
        admin = msg.sender;
    }

    function setEscrow(address newEscrow) external onlyAdmin {
        require(escrow == address(0), "escrow already set");
        escrow = newEscrow;
    }

    function setRate(uint256 _yearlyRate) public onlyAdmin {
        yearlyRate = _yearlyRate; // In basis points
    }

    function setAdmin(address account) public onlyAdmin {
        admin = account;
    }

    function balanceOf(address account) public view returns (uint256) {
        return staked[account];
    }

    function rewardRate() public view returns(uint256) {
        uint256 baseRewardRate = uint256(1e18).mul(yearlyRate).div(3.154e11); // 3.154e7 is number of seconds in a year, multiplied by e4 to make it basis point based.
        return baseRewardRate;
    }

    function stakedDuration(address account) public view returns(uint256) {
        uint256 secondsStaked = block.timestamp.sub(stakedFromTS[account]);
        return secondsStaked;
    }

    function earned(address account) public view returns(uint256) {
        return
            balanceOf(account)
                .mul(stakedDuration(account))
                .mul(rewardRate())
                .div(1e18) // Div by 1e18 to offset the base multiplier of 1e18 in rewardRate()
                .add(unclaimedRewards[account]);
    }

    function stake(uint256 amount) external {
        require(amount > 0, "amount is <= 0");
        require(token.balanceOf(msg.sender) >= amount, "balance is <= amount");
        token.transferFrom(msg.sender, address(this), amount);
        if (staked[msg.sender] > 0) {
            unclaimedRewards[msg.sender] = earned(msg.sender);
        }
        emit Staked(msg.sender, amount);
        stakedFromTS[msg.sender] = block.timestamp;
        staked[msg.sender] =  staked[msg.sender].add(amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "amount is <= 0");
        require(staked[msg.sender] >= amount, "amount is > staked");
        if (staked[msg.sender] > 0) {
            unclaimedRewards[msg.sender] = earned(msg.sender);
        }
        stakedFromTS[msg.sender] = block.timestamp;
        emit Withdrawn(msg.sender, amount);
        staked[msg.sender] = staked[msg.sender].sub(amount);
        token.transfer(msg.sender, amount);
    }

    function getReward() external {
        uint256 reward = earned(msg.sender);
        unclaimedRewards[msg.sender] = 0;
        stakedFromTS[msg.sender] = block.timestamp;
        IEscrow(escrow).disperseRewards(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }

}

interface IEscrow {
    function disperseRewards(address user, uint256 amount) external;
}