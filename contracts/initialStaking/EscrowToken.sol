pragma solidity 0.5.16;

import "../openzeppelin/ERC20Burnable.sol";
import "../openzeppelin/ERC20Detailed.sol";


contract EscrowToken is ERC20, ERC20Detailed, ERC20Burnable {

  constructor(uint256 amount) public
  ERC20Detailed("4.0 Escrow LP", "4.0 ESC", 18)
  {
    _mint(msg.sender, amount);
  }

}
