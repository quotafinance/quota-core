// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

interface Router {
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);
}

contract LiquidityExtension {
    address public router;

    constructor(address _router) {
        router = _router;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) external {
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountADesired);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountBDesired);
        IERC20(tokenA).approve(router, amountADesired);
        IERC20(tokenB).approve(router, amountBDesired);
        Router(router).addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin,
            msg.sender,
            block.timestamp + 10 minutes
        );
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin
    ) external payable {
        IERC20(token).transferFrom(
            msg.sender,
            address(this),
            amountTokenDesired
        );
        IERC20(token).approve(router, amountTokenDesired);
        (, uint amountETH, ) = Router(router).addLiquidityETH{value: msg.value}(
            token,
            amountTokenDesired,
            amountTokenMin,
            amountETHMin,
            msg.sender,
            block.timestamp + 10 minutes
        );
        if (msg.value > amountETH)
            transferDust();
    }

    function transferDust() internal {
        address liquidityProvider = msg.sender;
        payable(liquidityProvider).transfer(address(this).balance);
    }
}
