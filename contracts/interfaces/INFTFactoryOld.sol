//SPDX-License-Identifier: Unlicense
pragma solidity 0.5.16;

interface INFTFactory {
    function isHandler(address) external view returns (bool);
}