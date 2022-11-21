pragma solidity ^0.5.16;

// This contract is only used for Test setup since chainlink pricefeed for SNP500
contract ChainLinkAggregator {

    function latestRoundData()
    external pure
    returns(uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound)
    {
        return (18446744073709551629, 39603000000, 1668888244, 1668888244, 18446744073709551629);
    }
}