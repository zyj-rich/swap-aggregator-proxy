// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {TransferHelper} from "./libraries/SafeTransfer.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/ISwapAggregatorExecutor.sol";

// notice: external contract
contract Proxy {
    address public immutable WETH;
    address public immutable Owner;
    bool public Pause;

    address public immutable CommitOwner;
    address public immutable ConfirmOwner;
    address public Executor;
    address public UnConfirmExecutor;

    constructor(address _WETH, address _Owner, address _CommitOwner, address _ConfirmOwner ,address _Executor) {
        WETH = _WETH;
        Owner = _Owner;
        Executor = _Executor;
        CommitOwner = _CommitOwner;
        ConfirmOwner = _ConfirmOwner;
        UnConfirmExecutor = address(0);
        Pause = false;
    }

    function setExecutor(address _executor) external {
        require(_executor != address(0), "Zero executor address");
        if (msg.sender == CommitOwner) {
            UnConfirmExecutor = _executor;
        }else if (msg.sender == ConfirmOwner) {
            require(UnConfirmExecutor == _executor, "Executor inconsistent");
            Executor = UnConfirmExecutor;
            UnConfirmExecutor = address(0);
        }else {
            revert("Auth failed");
        }
    }

    modifier onlyOwner() {
        require(msg.sender == Owner, "WL");
        _;
    }

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "EXPIRED");
        _;
    }

    modifier verifySelector(bytes calldata path) {
        require(path.length >= 4, "path too short");
        bytes4 selector;
        assembly {
            selector := calldataload(path.offset)
        }
        require(ISwapAggregatorExecutor(Executor).executeSwapSelector() == selector, "CS");
        _;
    }

    modifier whenNoPause() {
        require(!Pause, "Pause");
        _;
    }

    function withdraw(address token, uint256 value) external onlyOwner {
        TransferHelper.safeTransfer(token, Owner, value);
    }

    function withdrawETH(uint256 value) external onlyOwner {
        TransferHelper.safeTransferETH(Owner, value);
    }

    function setPause(bool pause) external onlyOwner {
        Pause = pause;
    }

    receive() external payable {
        require(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
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
    ) external ensure(deadline) verifySelector(path) whenNoPause {
        require(amountOutMin > 0, "amountOutMin less than zero");

        TransferHelper.safeTransferFrom(tokenIn, msg.sender, Executor, amountIn);
        uint256 amountOutBefore = IERC20(tokenOut).balanceOf(address(this));

        (bool success,) = Executor.call(abi.encodePacked(path, amountOutMin));
        require(success, "SF");

        uint256 amountOut = IERC20(tokenOut).balanceOf(address(this)) - amountOutBefore;
        require(amountOut >= amountOutMin, "IS1");

        {
            // maybe token transfer fee
            amountOutBefore = IERC20(tokenOut).balanceOf(receiver);
            TransferHelper.safeTransfer(tokenOut, receiver, amountOut);
            require(IERC20(tokenOut).balanceOf(receiver) - amountOutBefore >= amountOutMin, "IS2");
        }
    }

    // swap eth to token
    function SwapExactETHForToken(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenOut,
        address receiver,
        bytes calldata path,
        uint256 deadline
    ) external payable ensure(deadline) verifySelector(path) whenNoPause {
        require(amountOutMin > 0, "amountOutMin less than zero");
        require(amountIn == msg.value, "SV");
        IWETH(WETH).deposit{value: amountIn}();

        TransferHelper.safeTransfer(WETH, Executor, amountIn);
        uint256 amountOutBefore = IERC20(tokenOut).balanceOf(address(this));

        (bool success,) = Executor.call(abi.encodePacked(path, amountOutMin));
        require(success, "SF");

        uint256 amountOut = IERC20(tokenOut).balanceOf(address(this)) - amountOutBefore;
        require(amountOut >= amountOutMin, "IS1");

        // maybe token transfer fee
        {
            amountOutBefore = IERC20(tokenOut).balanceOf(receiver);
            TransferHelper.safeTransfer(tokenOut, receiver, amountOut);
            require(IERC20(tokenOut).balanceOf(receiver) - amountOutBefore >= amountOutMin, "IS2");
        }
    }

    // swap token to eth
    function SwapExactTokenForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address receiver,
        bytes calldata path,
        uint256 deadline
    ) external ensure(deadline) verifySelector(path) whenNoPause {
        require(amountOutMin > 0, "amountOutMin less than zero");

        TransferHelper.safeTransferFrom(tokenIn, msg.sender, Executor, amountIn);
        uint256 amountOutBefore = IERC20(WETH).balanceOf(address(this));

        (bool success,) = Executor.call(abi.encodePacked(path, amountOutMin));
        require(success, "SF");

        uint256 amountOut = IERC20(WETH).balanceOf(address(this)) - amountOutBefore;
        require(amountOut >= amountOutMin, "IS");
        {
            IWETH(WETH).withdraw(amountOut);
            (success,) = receiver.call{value: amountOut}("");
            require(success, "ES");
        }
    }
}
