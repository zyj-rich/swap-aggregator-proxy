// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {TransferHelper} from "./libraries/SafeTransfer.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IWETH.sol";


// notice: external contract
contract Proxy {
    address public immutable WETH;
    address public immutable Owner;
    address private Executor;

    constructor(address _WETH, address _Owner,address _Executor) {
        WETH = _WETH;
        Owner = _Owner;
        Executor = _Executor;
    }

    modifier onlyOwner() {
        require(msg.sender == Owner, "WL");
        _;
    }

    function withdraw(address token, uint256 value) external onlyOwner {
        TransferHelper.safeTransfer(token, Owner, value);
    }

    function withdrawETH(uint256 value) external onlyOwner {
        TransferHelper.safeTransferETH(Owner, value);
    }

    function setExecutor(address _executor) external onlyOwner {
        require(_executor != address(0), "Invalid executor address");
        Executor = _executor;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "EXPIRED");
        _;
    }

    // swap token to token
    function SwapExactTokenForToken(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut,
        address receiver,
        bytes calldata path,
        uint256 deadline
    ) external ensure(deadline) {
        TransferHelper.safeTransferFrom(tokenIn, msg.sender, Executor, amountIn);

        uint256 amountOutBefore = IERC20(tokenOut).balanceOf(address(this));

        (bool success,) = Executor.call(abi.encodePacked(path, amountOutMin));
        require(success, "SF");

        uint256 amountOut = IERC20(tokenOut).balanceOf(address(this)) - amountOutBefore;
        require(amountOut >= amountOutMin, "IS1");

        // maybe token transfer fee
        amountOutBefore = IERC20(tokenOut).balanceOf(receiver);
        TransferHelper.safeTransfer(tokenOut, receiver, amountOut);
        require(IERC20(tokenOut).balanceOf(receiver) - amountOutBefore >= amountOutMin, "IS2");
    }

    // swap eth to token
    function SwapExactETHForToken(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenOut,
        address receiver,
        bytes calldata path,
        uint256 deadline
    ) external payable ensure(deadline) {
        require(amountIn == msg.value, "SV");
        IWETH(WETH).deposit{value: amountIn}();

        TransferHelper.safeTransfer(WETH, Executor, amountIn);

        uint256 amountOutBefore = IERC20(tokenOut).balanceOf(address(this));

        (bool success,) = Executor.call(abi.encodePacked(path, amountOutMin));
        require(success, "SF");

        uint256 amountOut = IERC20(tokenOut).balanceOf(address(this)) - amountOutBefore;
        require(amountOut >= amountOutMin, "IS1");

        // maybe token transfer fee
        amountOutBefore = IERC20(tokenOut).balanceOf(receiver);
        TransferHelper.safeTransfer(tokenOut, receiver, amountOut);
        require(IERC20(tokenOut).balanceOf(receiver) - amountOutBefore >= amountOutMin, "IS2");
    }

    // swap token to eth
    function SwapExactTokenForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address receiver,
        bytes calldata path,
        uint256 deadline
    ) external ensure(deadline) {
        TransferHelper.safeTransferFrom(tokenIn, msg.sender, Executor, amountIn);

        uint256 amountOutBefore = IERC20(WETH).balanceOf(address(this));

        (bool success,) = Executor.call(abi.encodePacked(path, amountOutMin));
        require(success, "SF");

        uint256 amountOut = IERC20(WETH).balanceOf(address(this)) - amountOutBefore;
        require(amountOut >= amountOutMin, "IS");

        IWETH(WETH).withdraw(amountOut);
        (success,) = receiver.call{value: amountOut}("");
        require(success, "ES");
    }
}
