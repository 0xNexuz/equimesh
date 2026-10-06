// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DeterministicPolicyGate.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

/**
 * @title EquiMeshVault
 * @notice Non-custodial thematic basket vault holding bStocks, xStocks, and Ondo USDY yield reserves.
 * Interacts with Binance Web3 Wallet Aggregated Router for swap execution under policy gate constraints.
 */
contract EquiMeshVault {
    address public immutable owner;
    DeterministicPolicyGate public immutable policyGate;

    // Track user deposit balances
    mapping(address => uint256) public userShares;
    uint256 public totalShares;

    event Deposit(address indexed user, uint256 amountUSD);
    event Withdrawal(address indexed user, uint256 shares);
    event RebalanceExecuted(address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    constructor(address _policyGate) {
        owner = msg.sender;
        policyGate = DeterministicPolicyGate(_policyGate);
    }

    /**
     * @notice Deposit funds into the basket vault.
     */
    function deposit(address token, uint256 amount) external {
        require(amount > 0, "Amount must be > 0");
        IERC20(token).transferFrom(msg.sender, address(this), amount);
        userShares[msg.sender] += amount;
        totalShares += amount;
        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice Execute an autonomous rebalance via Binance Web3 Wallet Aggregated Router.
     * Must be verified by the Deterministic Policy Gate.
     */
    function executeRebalance(
        address tokenIn,
        address tokenOut,
        uint256 amountInUSD,
        uint256 slippageBps,
        bytes calldata swapData
    ) external {
        // Enforce policy invariants on-chain
        bool approved = policyGate.verifyTrade(tokenIn, tokenOut, amountInUSD, slippageBps);
        require(approved, "Policy verification failed");

        // Swap execution logic with Binance router would occur here
        emit RebalanceExecuted(tokenIn, tokenOut, amountInUSD, 0);
    }

    /**
     * @notice Unconditional non-custodial withdrawal.
     */
    function withdraw(address token, uint256 shares) external {
        require(userShares[msg.sender] >= shares, "Insufficient shares");
        userShares[msg.sender] -= shares;
        totalShares -= shares;
        IERC20(token).transfer(msg.sender, shares);
        emit Withdrawal(msg.sender, shares);
    }
}
