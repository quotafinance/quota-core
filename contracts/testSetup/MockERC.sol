import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockERC is ERC20, Ownable {
    constructor(string memory name, string memory symbol, uint256 decimals) ERC20(name, symbol) {
        _mint(msg.sender, 1000 * 10**decimals);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}