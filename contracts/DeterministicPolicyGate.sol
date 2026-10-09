// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ReferencePriceOracle.sol";

/**
 * @title DeterministicPolicyGate
 * @author EquiMesh Engineering Team (BNB Hack: Tokenized Stocks Edition)
 * @notice Enforces immutable risk invariants and human governance over autonomous portfolio trading agents.
 * 
 * CORE INVARIANTS:
 * 1. Circuit Breaker Fail-Closed: Halts execution immediately upon activation.
 * 2. Token Allowlist: Execution strictly confined to approved tokenized stocks & RWA assets.
 * 3. Max Single Trade Size: Bounded to $5,000 USD per execution via oracle pricing.
 * 4. Max Slippage Cap: Maximum 100 bps (1.00%) slippage below fair value.
 * 5. Temporal Rate Limiting: 15-minute cooldown between rebalances.
 * 6. Authorization: Restricted to registered vault and authorized governance.
 */
contract DeterministicPolicyGate {
    address public immutable owner;
    address public agentExecutor;
    address public authorizedVault;
    IReferencePriceOracle public oracle;

    bool public circuitBreakerActive;
    uint256 public maxSlippageBps = 100; // 1.00% (100 basis points)
    uint256 public maxSingleTradeUSD = 5000 * 1e18; // $5,000 in 18-decimal USD base
    uint256 public cooldownSeconds = 900; // 15 minutes (900 seconds)
    uint256 public lastExecutionTimestamp;

    mapping(address => bool) public allowlistedTokens;

    event PolicyVerified(
        address indexed caller,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 valueInUSD
    );
    event CircuitBreakerToggled(bool active, address indexed triggeredBy);
    event PolicyUpdated(uint256 newSlippageBps, uint256 newMaxTradeUSD, uint256 newCooldown);
    event AuthorizedVaultSet(address indexed vault);
    event AgentExecutorSet(address indexed agent);
    event OracleSet(address indexed oracle);

    error CircuitBreakerEngaged();
    error UnauthorizedCaller();
    error TradeExceedsMaximumSize(uint256 valueUSD, uint256 maximumUSD);
    error SlippageExceedsCap(uint256 minAmountOut, uint256 requiredMinOut);
    error CooldownNotElapsed(uint256 elapsed, uint256 required);
    error TokenNotAllowlisted(address token);
    error IdenticalTokens();
    error ZeroAddress();

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    modifier onlyAuthorizedVault() {
        if (msg.sender != authorizedVault && msg.sender != owner) {
            revert UnauthorizedCaller();
        }
        _;
    }

    constructor(address _agentExecutor, address _oracle) {
        if (_agentExecutor == address(0) || _oracle == address(0)) revert ZeroAddress();
        owner = msg.sender;
        agentExecutor = _agentExecutor;
        oracle = IReferencePriceOracle(_oracle);
        circuitBreakerActive = false;
    }

    function setAuthorizedVault(address _vault) external onlyOwner {
        if (_vault == address(0)) revert ZeroAddress();
        authorizedVault = _vault;
        emit AuthorizedVaultSet(_vault);
    }

    function setAgentExecutor(address _agent) external onlyOwner {
        if (_agent == address(0)) revert ZeroAddress();
        agentExecutor = _agent;
        emit AgentExecutorSet(_agent);
    }

    function setOracle(address _oracle) external onlyOwner {
        if (_oracle == address(0)) revert ZeroAddress();
        oracle = IReferencePriceOracle(_oracle);
        emit OracleSet(_oracle);
    }

    function setTokenAllowlist(address token, bool allowed) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        allowlistedTokens[token] = allowed;
    }

    function toggleCircuitBreaker() external onlyOwner {
        circuitBreakerActive = !circuitBreakerActive;
        emit CircuitBreakerToggled(circuitBreakerActive, msg.sender);
    }

    function updatePolicy(
        uint256 newSlippageBps,
        uint256 newMaxTradeUSD,
        uint256 newCooldown
    ) external onlyOwner {
        require(newSlippageBps <= 500, "Slippage cap cannot exceed 500 bps");
        require(newMaxTradeUSD > 0, "Max trade size must be > 0");
        maxSlippageBps = newSlippageBps;
        maxSingleTradeUSD = newMaxTradeUSD;
        cooldownSeconds = newCooldown;
        emit PolicyUpdated(newSlippageBps, newMaxTradeUSD, newCooldown);
    }

    /**
     * @notice Read-only view function verifying all deterministic policy invariants without state mutation.
     * Takes exact token amounts and validates against oracle fair valuation.
     */
    function verifyTrade(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) public view returns (bool) {
        // Invariant 1: Circuit Breaker Fail-Closed
        if (circuitBreakerActive) {
            revert CircuitBreakerEngaged();
        }

        // Invariant 2: Allowlisted tokens only (and distinct assets)
        if (tokenIn == tokenOut) revert IdenticalTokens();
        if (!allowlistedTokens[tokenIn]) revert TokenNotAllowlisted(tokenIn);
        if (!allowlistedTokens[tokenOut]) revert TokenNotAllowlisted(tokenOut);

        // Invariant 3: Single Trade Cap (Evaluated via Oracle)
        uint256 valueInUSD = oracle.getAssetValueUSD(tokenIn, amountIn);
        if (valueInUSD > maxSingleTradeUSD) {
            revert TradeExceedsMaximumSize(valueInUSD, maxSingleTradeUSD);
        }

        // Invariant 4: Slippage Bounds (minAmountOut must be within maxSlippageBps of fair value)
        (uint256 priceOutUSD, uint8 decimalsOut) = oracle.getPriceUSD(tokenOut);
        uint256 expectedOut = (valueInUSD * (10 ** decimalsOut)) / priceOutUSD;
        uint256 requiredMinOut = (expectedOut * (10000 - maxSlippageBps)) / 10000;
        if (minAmountOut < requiredMinOut) {
            revert SlippageExceedsCap(minAmountOut, requiredMinOut);
        }

        // Invariant 5: Rate Limiting / Temporal Cooldown
        if (lastExecutionTimestamp > 0 && block.timestamp < lastExecutionTimestamp + cooldownSeconds) {
            revert CooldownNotElapsed(block.timestamp - lastExecutionTimestamp, cooldownSeconds);
        }

        return true;
    }

    /**
     * @notice Read-only check for UI pre-flight validation using abstract USD amount and slippage basis points.
     */
    function verifyTradeUSD(
        address tokenIn,
        address tokenOut,
        uint256 amountInUSD,
        uint256 slippageBps
    ) external view returns (bool) {
        if (circuitBreakerActive) revert CircuitBreakerEngaged();
        if (tokenIn == tokenOut) revert IdenticalTokens();
        if (!allowlistedTokens[tokenIn]) revert TokenNotAllowlisted(tokenIn);
        if (!allowlistedTokens[tokenOut]) revert TokenNotAllowlisted(tokenOut);
        if (amountInUSD > maxSingleTradeUSD) revert TradeExceedsMaximumSize(amountInUSD, maxSingleTradeUSD);
        if (slippageBps > maxSlippageBps) revert SlippageExceedsCap(slippageBps, maxSlippageBps);
        if (lastExecutionTimestamp > 0 && block.timestamp < lastExecutionTimestamp + cooldownSeconds) {
            revert CooldownNotElapsed(block.timestamp - lastExecutionTimestamp, cooldownSeconds);
        }
        return true;
    }

    /**
     * @notice Verifies all deterministic policy invariants and records execution timestamp.
     * Can ONLY be invoked by the authorized vault or owner during genuine rebalance settlement.
     * Prevents external griefing or burn attacks on the cooldown period.
     */
    function verifyAndRecordTrade(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut
    ) external onlyAuthorizedVault returns (bool) {
        verifyTrade(tokenIn, tokenOut, amountIn, minAmountOut);

        uint256 valueInUSD = oracle.getAssetValueUSD(tokenIn, amountIn);
        lastExecutionTimestamp = block.timestamp;
        emit PolicyVerified(msg.sender, tokenIn, tokenOut, amountIn, minAmountOut, valueInUSD);
        return true;
    }
}
