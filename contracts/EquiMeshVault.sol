// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./DeterministicPolicyGate.sol";
import "./ReferencePriceOracle.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
}

interface ISwapRouter {
    function executeSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient
    ) external returns (uint256 amountOut);
}

/**
 * @title EquiMeshVault
 * @author EquiMesh Engineering Team
 * @notice Institutional-grade, policy-governed non-custodial thematic basket vault.
 * Enforces mathematically sound proportional share accounting and post-trade balance reconciliation.
 */
contract EquiMeshVault {
    address public immutable owner;
    DeterministicPolicyGate public immutable policyGate;
    IReferencePriceOracle public immutable oracle;
    address public agentExecutor;

    mapping(address => uint256) public userShares;
    uint256 public totalShares;

    address[] public heldTokens;
    mapping(address => bool) public isHeldToken;

    event Deposit(address indexed user, address indexed token, uint256 amount, uint256 sharesMinted);
    event Withdrawal(address indexed user, uint256 sharesBurned);
    event RebalanceExecuted(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 timestamp
    );
    event AgentExecutorUpdated(address indexed newAgent);

    error UnauthorizedCaller();
    error InsufficientShares();
    error ZeroAmount();
    error UnallowlistedAsset(address token);
    error InsufficientVaultBalance(address token, uint256 available, uint256 required);
    error SlippageInvariantBreached(uint256 actualOut, uint256 minRequiredOut);
    error SwapExecutionFailed();

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    modifier onlyAgentOrOwner() {
        if (msg.sender != agentExecutor && msg.sender != owner) {
            revert UnauthorizedCaller();
        }
        _;
    }

    constructor(address _policyGate, address _oracle, address _agentExecutor) {
        require(_policyGate != address(0) && _oracle != address(0), "Zero address");
        owner = msg.sender;
        policyGate = DeterministicPolicyGate(_policyGate);
        oracle = IReferencePriceOracle(_oracle);
        agentExecutor = _agentExecutor;
    }

    function setAgentExecutor(address _newAgent) external onlyOwner {
        require(_newAgent != address(0), "Zero address");
        agentExecutor = _newAgent;
        emit AgentExecutorUpdated(_newAgent);
    }

    function registerHeldToken(address token) public onlyOwner {
        require(policyGate.allowlistedTokens(token), "Token must be allowlisted");
        if (!isHeldToken[token]) {
            heldTokens.push(token);
            isHeldToken[token] = true;
        }
    }

    function getHeldTokens() external view returns (address[] memory) {
        return heldTokens;
    }

    /**
     * @notice Calculate total Net Asset Value (NAV) of all tokens held in the vault in 18-decimal USD.
     */
    function totalValueUSD() public view returns (uint256 navUSD) {
        uint256 total = 0;
        for (uint256 i = 0; i < heldTokens.length; i++) {
            address token = heldTokens[i];
            uint256 bal = IERC20(token).balanceOf(address(this));
            if (bal > 0) {
                total += oracle.getAssetValueUSD(token, bal);
            }
        }
        return total;
    }

    /**
     * @notice Deposit an allowlisted asset into the vault.
     * Mints proportional shares based on deposit USD value vs total vault NAV.
     */
    function deposit(address token, uint256 amount) external returns (uint256 sharesMinted) {
        if (amount == 0) revert ZeroAmount();
        if (!policyGate.allowlistedTokens(token)) revert UnallowlistedAsset(token);

        if (!isHeldToken[token]) {
            heldTokens.push(token);
            isHeldToken[token] = true;
        }

        uint256 prevNavUSD = totalValueUSD();
        uint256 depositValUSD = oracle.getAssetValueUSD(token, amount);

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        if (totalShares == 0 || prevNavUSD == 0) {
            sharesMinted = depositValUSD;
        } else {
            sharesMinted = (depositValUSD * totalShares) / prevNavUSD;
        }

        userShares[msg.sender] += sharesMinted;
        totalShares += sharesMinted;

        emit Deposit(msg.sender, token, amount, sharesMinted);
        return sharesMinted;
    }

    /**
     * @notice Non-custodial withdrawal. Burns shares and transfers proportional slice of every asset held.
     * Prevents arbitrary drain attacks.
     */
    function withdraw(uint256 shares) external {
        if (shares == 0) revert ZeroAmount();
        if (userShares[msg.sender] < shares) revert InsufficientShares();

        uint256 currentTotalShares = totalShares;
        userShares[msg.sender] -= shares;
        totalShares -= shares;

        for (uint256 i = 0; i < heldTokens.length; i++) {
            address token = heldTokens[i];
            uint256 vaultBal = IERC20(token).balanceOf(address(this));
            if (vaultBal > 0) {
                uint256 payout = (vaultBal * shares) / currentTotalShares;
                if (payout > 0) {
                    IERC20(token).transfer(msg.sender, payout);
                }
            }
        }

        emit Withdrawal(msg.sender, shares);
    }

    /**
     * @notice Executes a policy-governed rebalance via verified router call.
     * Enforces pre-trade and post-trade balance reconciliation.
     */
    function executeRebalance(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address router,
        bytes calldata routerCallData
    ) external onlyAgentOrOwner returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();

        // 1. Enforce on-chain policy invariants via policy gate
        policyGate.verifyAndRecordTrade(tokenIn, tokenOut, amountIn, minAmountOut);

        // 2. Pre-trade balance verification
        uint256 balInBefore = IERC20(tokenIn).balanceOf(address(this));
        if (balInBefore < amountIn) {
            revert InsufficientVaultBalance(tokenIn, balInBefore, amountIn);
        }
        uint256 balOutBefore = IERC20(tokenOut).balanceOf(address(this));

        // 3. Register tokenOut if new asset
        if (!isHeldToken[tokenOut]) {
            heldTokens.push(tokenOut);
            isHeldToken[tokenOut] = true;
        }

        // 4. Approve router for exact amount
        IERC20(tokenIn).approve(router, amountIn);

        // 5. Execute swap via router call
        (bool success, ) = router.call(routerCallData);
        if (!success) revert SwapExecutionFailed();

        // 6. Post-trade balance reconciliation
        uint256 balInAfter = IERC20(tokenIn).balanceOf(address(this));
        uint256 balOutAfter = IERC20(tokenOut).balanceOf(address(this));

        require(balInBefore - balInAfter == amountIn, "Input balance mismatch");
        amountOut = balOutAfter - balOutBefore;

        if (amountOut < minAmountOut) {
            revert SlippageInvariantBreached(amountOut, minAmountOut);
        }

        emit RebalanceExecuted(tokenIn, tokenOut, amountIn, amountOut, block.timestamp);
        return amountOut;
    }
}
