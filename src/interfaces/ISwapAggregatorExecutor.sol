pragma solidity >=0.5.0;

interface ISwapAggregatorExecutor {
    function executeSwapSelector() external pure returns (bytes4);
}