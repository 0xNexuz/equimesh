// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../ReferencePriceOracle.sol";
import "./MockERC20.sol";

/**
 * @title MockSwapRouter
 * @notice Deterministic DEX swap router executing genuine token movements based on oracle pricing.
 * Can simulate custom slippage to test adversarial and edge scenarios.
 */
contract MockSwapRouter {
    IReferencePriceOracle public immutable oracle;
    uint256 public forcedSlippageBps = 0; // 0 = fair execution, > 0 = simulate slippage penalty

    event SwapExecuted(
        address indexed caller,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address recipient
    );

    constructor(address _oracle) {
        oracle = IReferencePriceOracle(_oracle);
    }

    function setForcedSlippageBps(uint256 bps) external {
        forcedSlippageBps = bps;
    }

    /**
     * @notice Execute a swap from tokenIn to tokenOut.
     * Pulls amountIn from msg.sender and transfers amountOut to recipient.
     */
    function executeSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) external returns (uint256 amountOut) {
        require(amountIn > 0, "Zero amountIn");

        // 1. Pull tokenIn from caller
        MockERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        // 2. Compute fair amountOut via oracle
        uint256 valueInUSD = oracle.getAssetValueUSD(tokenIn, amountIn);
        (uint256 priceOutUSD, uint8 decimalsOut) = oracle.getPriceUSD(tokenOut);
        uint256 fairOut = (valueInUSD * (10 ** decimalsOut)) / priceOutUSD;

        // Apply forced slippage simulation if configured
        if (forcedSlippageBps > 0) {
            amountOut = (fairOut * (10000 - forcedSlippageBps)) / 10000;
        } else {
            amountOut = fairOut;
        }

        require(amountOut >= minAmountOut, "Router: Slippage limit exceeded");

        // 3. Ensure router has sufficient tokenOut to pay recipient, or mint if mock
        if (MockERC20(tokenOut).balanceOf(address(this)) < amountOut) {
            MockERC20(tokenOut).mint(address(this), amountOut);
        }

        MockERC20(tokenOut).transfer(recipient, amountOut);
        emit SwapExecuted(msg.sender, tokenIn, tokenOut, amountIn, amountOut, recipient);
        return amountOut;
    }
}
