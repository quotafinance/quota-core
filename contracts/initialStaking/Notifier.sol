pragma solidity 0.5.16;

import "../openzeppelin/Ownable.sol";
import "./PoolEscrow.sol";

contract Notifier is Ownable {

  event Notified(address);

  constructor() public {}

  function notify(address[] memory pools, uint256 amount, address token, uint256 tokenAmount) public onlyOwner {
    for (uint256 i = 0; i < pools.length; i++) {
      // notify pool
      TokenRewards(pools[i]).notifyRewardAmount(amount);
      emit Notified(pools[i]);

      // transfer to pool's escow
      PoolEscrow escrow = PoolEscrow(TokenRewards(pools[i]).escrow());
      IERC20(token).transferFrom(msg.sender, address(escrow), tokenAmount);

      // revert transaction if anything is wrong
      require(address(escrow) != address(0), "escrow not set");
      require(IERC20(escrow.shareToken()).balanceOf(pools[i]) == amount, "wrong amount");
    }
  }
}