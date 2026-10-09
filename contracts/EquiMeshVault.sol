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
 * Enforces mathematically sound proportional share accounting, router allowlists,
 * reentrancy protection, SafeERC20 semantics, and post-trade balance reconciliation.
 */
contract EquiMeshVault {
    address public immutable owner;
    DeterministicPolicyGate public immutable policyGate;
    IReferencePriceOracle public immutable oracle;
    address public agentExecutor;

    // Minimum shares minted for initial deposit to prevent zero-share inflation attacks
    uint256 public constant MIN_INITIAL_SHARES = 1000;

    mapping(address => uint256) public userShares;
    uint256 public totalShares;

    address[] public heldTokens;
    mapping(address => bool) public isHeldToken;

    // Approved router registry
    mapping(address => bool) public approvedRouters;

    // Reentrancy guard state
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _reentrancyStatus;

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
    event RouterApprovalSet(address indexed router, bool approved);

    error UnauthorizedCaller();
    error InsufficientShares();
    error ZeroAmount();
    error ZeroSharesMinted();
    error UnallowlistedAsset(address token);
    error UnapprovedRouter(address router);
    error InsufficientVaultBalance(address token, uint256 available, uint256 required);
    error SlippageInvariantBreached(uint256 actualOut, uint256 minRequiredOut);
    error SwapExecutionFailed();
    error InvalidCalldata();
    error ReentrantCall();
    error SafeTransferFailed();
    error ZeroAddress();

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

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert ReentrantCall();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    constructor(address _policyGate, address _oracle, address _agentExecutor) {
        if (_policyGate == address(0) || _oracle == address(0)) revert ZeroAddress();
        owner = msg.sender;
        policyGate = DeterministicPolicyGate(_policyGate);
        oracle = IReferencePriceOracle(_oracle);
        agentExecutor = _agentExecutor;
        _reentrancyStatus = _NOT_ENTERED;
    }

    function setAgentExecutor(address _newAgent) external onlyOwner {
        if (_newAgent == address(0)) revert ZeroAddress();
        agentExecutor = _newAgent;
        emit AgentExecutorUpdated(_newAgent);
    }

    function setRouterApproval(address router, bool approved) external onlyOwner {
        if (router == address(0)) revert ZeroAddress();
        approvedRouters[router] = approved;
        emit RouterApprovalSet(router, approved);
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
     * Normalized across different token native decimal bases (e.g. 6-dec USDT, 18-dec bNVDA).
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
     * Protected against reentrancy, fee-on-transfer discrepancies, and zero-share inflation attacks.
     */
    function deposit(address token, uint256 amount) external nonReentrant returns (uint256 sharesMinted) {
        if (amount == 0) revert ZeroAmount();
        if (!policyGate.allowlistedTokens(token)) revert UnallowlistedAsset(token);

        if (!isHeldToken[token]) {
            heldTokens.push(token);
            isHeldToken[token] = true;
        }

        uint256 prevNavUSD = totalValueUSD();
        uint256 depositValUSD = oracle.getAssetValueUSD(token, amount);
        if (depositValUSD == 0) revert ZeroAmount();

        uint256 balBefore = IERC20(token).balanceOf(address(this));
        _safeTransferFrom(token, msg.sender, address(this), amount);
        uint256 balAfter = IERC20(token).balanceOf(address(this));
        require(balAfter - balBefore == amount, "Fee-on-transfer tokens unsupported");

        if (totalShares == 0 || prevNavUSD == 0) {
            sharesMinted = depositValUSD;
            if (sharesMinted < MIN_INITIAL_SHARES) {
                revert ZeroSharesMinted();
            }
        } else {
            // Round down in favor of existing vault shareholders
            sharesMinted = (depositValUSD * totalShares) / prevNavUSD;
            if (sharesMinted == 0) {
                revert ZeroSharesMinted();
            }
        }

        userShares[msg.sender] += sharesMinted;
        totalShares += sharesMinted;

        emit Deposit(msg.sender, token, amount, sharesMinted);
        return sharesMinted;
    }

    /**
     * @notice Non-custodial withdrawal. Burns shares and transfers proportional slice of every asset held.
     * Protected against reentrancy and arbitrary drain attacks.
     */
    function withdraw(uint256 shares) external nonReentrant {
        if (shares == 0) revert ZeroAmount();
        if (userShares[msg.sender] < shares) revert InsufficientShares();

        uint256 currentTotalShares = totalShares;
        userShares[msg.sender] -= shares;
        totalShares -= shares;

        for (uint256 i = 0; i < heldTokens.length; i++) {
            address token = heldTokens[i];
            uint256 vaultBal = IERC20(token).balanceOf(address(this));
            if (vaultBal > 0) {
                // Round down in favor of vault reserves
                uint256 payout = (vaultBal * shares) / currentTotalShares;
                if (payout > 0) {
                    _safeTransfer(token, msg.sender, payout);
                }
            }
        }

        emit Withdrawal(msg.sender, shares);
    }

    /**
     * @notice Executes a policy-governed rebalance via verified router call.
     * Enforces router allowlist, calldata parameter binding, balance reconciliation,
     * and zeroing allowances before and after execution.
     */
    function executeRebalance(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        address router,
        bytes calldata routerCallData
    ) external onlyAgentOrOwner nonReentrant returns (uint256 amountOut) {
        if (amountIn == 0) revert ZeroAmount();
        if (!approvedRouters[router]) revert UnapprovedRouter(router);

        // 1. Calldata verification: ensure tightly bound to executeSwap with recipient = this
        if (routerCallData.length >= 4 + 32 * 5) {
            bytes4 selector = bytes4(routerCallData);
            if (selector != ISwapRouter.executeSwap.selector) {
                revert InvalidCalldata();
            }
            (
                address decTokenIn,
                address decTokenOut,
                uint256 decAmountIn,
                uint256 decMinOut,
                address decRecipient
            ) = abi.decode(routerCallData[4:], (address, address, uint256, uint256, address));

            if (decTokenIn != tokenIn || decTokenOut != tokenOut) revert InvalidCalldata();
            if (decAmountIn != amountIn || decMinOut != minAmountOut) revert InvalidCalldata();
            if (decRecipient != address(this)) revert InvalidCalldata();
        } else {
            revert InvalidCalldata();
        }

        // 2. Enforce on-chain policy invariants via policy gate
        policyGate.verifyAndRecordTrade(tokenIn, tokenOut, amountIn, minAmountOut);

        // 3. Pre-trade balance verification
        uint256 balInBefore = IERC20(tokenIn).balanceOf(address(this));
        if (balInBefore < amountIn) {
            revert InsufficientVaultBalance(tokenIn, balInBefore, amountIn);
        }
        uint256 balOutBefore = IERC20(tokenOut).balanceOf(address(this));

        // 4. Register tokenOut if new asset
        if (!isHeldToken[tokenOut]) {
            heldTokens.push(tokenOut);
            isHeldToken[tokenOut] = true;
        }

        // 5. Zero allowance first, then approve router for exact amount
        _safeApprove(tokenIn, router, 0);
        _safeApprove(tokenIn, router, amountIn);

        // 6. Execute swap via router call
        (bool success, ) = router.call(routerCallData);
        if (!success) revert SwapExecutionFailed();

        // 7. Reset router allowance to 0 immediately after execution
        _safeApprove(tokenIn, router, 0);

        // 8. Post-trade balance reconciliation
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

    // --- Internal SafeERC20 Helpers ---

    function _safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeTransferFailed();
        }
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeTransferFailed();
        }
    }

    function _safeApprove(address token, address spender, uint256 value) internal {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.approve.selector, spender, value)
        );
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) {
            revert SafeTransferFailed();
        }
    }
}
