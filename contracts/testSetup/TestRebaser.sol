pragma solidity ^0.5.16;

import "./TestBasicRebaser.sol";
import "../ChainlinkOracle.sol";
import "../UniswapOracle.sol";

contract TestRebaser is  TestBasicRebaser, UniswapOracle, ChainlinkOracle {

  constructor (address router, address usdc, address wNative, address token, address _treasury, address oracle, address _taxManager)
  TestBasicRebaser(token, _treasury, _taxManager)
  ChainlinkOracle(oracle)
  UniswapOracle(router, usdc, wNative, token) public {
  }

}