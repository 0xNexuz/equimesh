// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title DeterministicPolicyGate
 * @author EquiMesh Engineering Team (BNB Hack: Tokenized Stocks Edition)
 * @notice Enforces immutable risk invariants and human approval controls over autonomous trading agents.
 * 
 * CORE INVARIANTS:
 * 1. Max Slippage Cap (Default 100 bps / 1.0%)
 * 2. Max Single Trade Size ($5,000 USD limit)
 * 3. Temporal Rate Limiting (Cooldown period between rebalances)
 * 4. Token Allowlist (Strictly restricted to approved RWAs and yield assets)
 * 5. Emergency Human Circuit Breaker (Fail-Closed: halts all autonomous execution)
 */
contract DeterministicPolicyGate {
    address public immutable owner;
    address public agentExecutor;

    bool public circuitBreakerActive;
    uint256 public maxSlippageBps = 100; // 1.0%
    uint256 public maxSingleTradeUSD = 5000 * 1e18; // $5,000 in 18-decimal base
    uint256 public cooldownSeconds = 900; // 15 minutes
    uint256 public lastExecutionTimestamp;

    mapping(address => bool) public allowlistedTokens;

    event PolicyVerified(address indexed agent, address tokenIn, address tokenOut, uint256 amountIn, uint256 expectedOut);
    event CircuitBreakerToggled(bool active, address indexed triggeredBy);
    event PolicyUpdated(uint256 newSlippageBps, uint256 newMaxTradeUSD, uint256 newCooldown);

    error CircuitBreakerEngaged();
    error UnauthorizedAgent();
    error TradeExceedsMaximumSize(uint256 provided, uint256 maximum);
    error SlippageExceedsCap(uint256 slippageBps, uint256 maxBps);
    error CooldownNotElapsed(uint256 elapsed, uint256 required);
    error TokenNotAllowlisted(address token);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    modifier onlyAgentOrOwner() {
        require(msg.sender == agentExecutor || msg.sender == owner, "Unauthorized caller");
        _;
    }

    constructor(address _agentExecutor) {
        owner = msg.sender;
        agentExecutor = _agentExecutor;
        circuitBreakerActive = false;
    }

    /**
     * @notice Set allowlist status for tokenized stock or yield asset.
     */
    function setTokenAllowlist(address token, bool allowed) external onlyOwner {
        allowlistedTokens[token] = allowed;
    }

    /**
     * @notice Toggle the emergency human circuit breaker (Fail-Closed).
     */
    function toggleCircuitBreaker() external onlyOwner {
        circuitBreakerActive = !circuitBreakerActive;
        emit CircuitBreakerToggled(circuitBreakerActive, msg.sender);
    }

    /**
     * @notice Verifies that a proposed trade satisfies all policy invariants before execution.
     */
    function verifyTrade(
        address tokenIn,
        address tokenOut,
        uint256 amountInUSD,
        uint256 slippageBps
    ) external onlyAgentOrOwner returns (bool) {
        // Invariant 1: Circuit Breaker Fail-Closed
        if (circuitBreakerActive) {
            revert CircuitBreakerEngaged();
        }

        // Invariant 2: Allowlisted tokens only
        if (!allowlistedTokens[tokenIn]) revert TokenNotAllowlisted(tokenIn);
        if (!allowlistedTokens[tokenOut]) revert TokenNotAllowlisted(tokenOut);

        // Invariant 3: Single Trade Cap
        if (amountInUSD > maxSingleTradeUSD) {
            revert TradeExceedsMaximumSize(amountInUSD, maxSingleTradeUSD);
        }

        // Invariant 4: Slippage Cap
        if (slippageBps > maxSlippageBps) {
            revert SlippageExceedsCap(slippageBps, maxSlippageBps);
        }

        // Invariant 5: Rate Limiting / Cooldown
        if (lastExecutionTimestamp > 0 && block.timestamp < lastExecutionTimestamp + cooldownSeconds) {
            revert CooldownNotElapsed(block.timestamp - lastExecutionTimestamp, cooldownSeconds);
        }

        lastExecutionTimestamp = block.timestamp;
        emit PolicyVerified(msg.sender, tokenIn, tokenOut, amountInUSD, slippageBps);
        return true;
    }
}
