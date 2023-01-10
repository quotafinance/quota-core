pragma solidity 0.5.16;

import "../openzeppelin/ERC20Burnable.sol";
import "../openzeppelin/ERC20Detailed.sol";


contract EscrowToken is ERC20, ERC20Detailed, ERC20Burnable {
  address public owner;
  constructor(uint256 amount) public
  ERC20Detailed("4.0 Escrow LP", "4.0 ESC", 18)
  {
    owner = msg.sender;
    _mint(msg.sender, amount);
  }
  function recoverTokens(
    address _token,
    address benefactor
  ) public {
    require(owner == msg.sender, "Only Owner");
    uint256 tokenBalance = IERC20(_token).balanceOf(address(this));
    IERC20(_token).transfer(benefactor, tokenBalance);
  }

}
