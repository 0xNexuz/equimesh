# 05. Invariants — EquiMesh

These 15 institutional on-chain and financial invariants are mathematically enforced and proven by `test/contracts_invariants.test.js` against compiled Solidity 0.8.20 bytecode executing on local EVM.

### Invariant 1 (INV-01): Proportional Share Accounting & Non-Custodial Multi-Asset NAV
- **Rule:** Depositors receive vault shares proportional to the total USD Net Asset Value (NAV) of the basket at the moment of deposit. On withdrawal, users burn shares to redeem an exact proportional slice of every underlying asset held in the vault. No depositor can withdraw more value than their share ratio permits.
- **Enforcement:** Enforced in `EquiMeshVault.deposit` and `EquiMeshVault.withdraw`. Completely eliminates 1:1 token drain attacks.
- **Status:** **PROVEN ON EVM** (`test/contracts_invariants.test.js`, Invariant 1).

### Invariant 2 (INV-02): Emergency Human Circuit Breaker (Fail-Closed)
- **Rule:** When the emergency kill switch is engaged, ALL autonomous execution paths halt immediately and fail-closed. No swaps, trades, or rebalances can execute under any circumstances.
- **Enforcement:** Checked first in `DeterministicPolicyGate.verifyTrade` and `DeterministicPolicyGate.verifyAndRecordTrade`; reverts unconditionally with `CircuitBreakerEngaged()`.
- **Status:** **PROVEN ON EVM** (`test/contracts_invariants.test.js`, Invariant 2).

### Invariant 3 (INV-03): Token Allowlist Strict Containment
- **Rule:** The vault and policy gate strictly restrict trading to verified tokenized stocks and compliant RWA assets (bNVDA, bAAPL, bTSLA, bMSFT, Ondo-USDY, USDT). Unapproved tokens or malicious contracts are rejected.
- **Enforcement:** Reverts with `TokenNotAllowlisted(address token)`.
- **Status:** **PROVEN ON EVM** (`test/contracts_invariants.test.js`, Invariant 3).

### Invariant 4 (INV-04): Single Trade Size Ceiling ($5,000 USD Limit)
- **Rule:** No single autonomous rebalance execution can exceed $5,000.00 USD equivalent valuation, preventing outsized capital losses from rogue triggers.
- **Enforcement:** Smart contract calculates USD trade size via `ReferencePriceOracle.getAssetValueUSD`; reverts with `TradeExceedsMaximumSize(uint256 valueUSD, uint256 maximumUSD)`.
- **Status:** **PROVEN ON EVM** (`test/contracts_invariants.test.js`, Invariant 4).

### Invariant 5 (INV-05): Maximum Slippage Bounds (100 bps / 1.00% Cap)
- **Rule:** No swap may execute if the expected price impact or slippage exceeds 100 basis points (1.00%) below fair oracle valuation.
- **Enforcement:** Verified on-chain before trade broadcast; reverts with `SlippageExceedsCap(uint256 minAmountOut, uint256 requiredMinOut)`.
- **Status:** **PROVEN ON EVM** (`test/contracts_invariants.test.js`, Invariant 5).

### Invariant 6 (INV-06): Genuine Token Rebalance & Balance Reconciliation
- **Rule:** After trade routing, the vault confirms that input tokens decreased by exactly `amountIn` and output tokens increased by at least `minAmountOut`.
- **Enforcement:** Pre/post balance deltas verified in `EquiMeshVault.executeRebalance`; reverts with `SlippageInvariantBreached` or `Input balance mismatch`.
- **Status:** **PROVEN ON EVM** (`test/contracts_invariants.test.js`, Invariant 6).

### Invariant 7 (INV-07): Temporal Rate Limiting (15-Minute Cooldown Mutex)
- **Rule:** Consecutive rebalance transactions must be separated by at least 900 seconds (15 minutes), preventing runaway execution loops and high-frequency draining.
- **Enforcement:** Smart contract records `lastExecutionTimestamp` and checks `block.timestamp >= lastExecutionTimestamp + cooldownSeconds`; reverts with `CooldownNotElapsed`.
- **Status:** **PROVEN ON EVM** (`test/contracts_invariants.test.js`, Invariant 7).

### Invariant 8 (INV-08): Router Allowlist Security (Unapproved Router Blocked)
- **Rule:** The vault restricts DEX interaction to explicitly approved routers registered in `approvedRouters[router]`. Untrusted or arbitrary third-party contracts cannot be invoked.
- **Enforcement:** Verified in `EquiMeshVault.executeRebalance`; reverts with `UnapprovedRouter(address router)`.
- **Status:** **PROVEN ON EVM** (`test/contracts_invariants.test.js`, Invariant 8).

### Invariant 9 (INV-09): Router Calldata Parameter & Recipient Binding
- **Rule:** Swap calldata is strictly decoded and bound to verified swap selectors. Recipient address must strictly equal `address(this)`, preventing attackers from diverting swapped output funds to external wallets.
- **Enforcement:** Calldata length, function selector, input/output tokens, and recipient checks in `EquiMeshVault.executeRebalance`; reverts with `InvalidCalldata()`.
- **Status:** **PROVEN ON EVM** (`test/contracts_invariants.test.js`, Invariant 9).

### Invariant 10 (INV-10): Fail-Closed Oracle Freshness & Sanity Bounds
- **Rule:** Price quotes older than `maxStaleness` (default 24 hours) or outside sanity bounds ($0.0001 to $10,000,000) are rejected fail-closed.
- **Enforcement:** Enforced in `ReferencePriceOracle.getPriceUSD` and `getAssetValueUSD`; reverts with `OraclePriceStale` or `PriceOutOfBounds`.
- **Status:** **PROVEN ON EVM** (`test/contracts_invariants.test.js`, Invariant 10).

### Invariant 11 (INV-11): Zero-Share Minting & Dust Inflation Protection
- **Rule:** Initial deposits must satisfy minimum initial share creation (`MIN_INITIAL_SHARES = 1000`). Subsequent deposits that round down to zero shares minted are reverted.
- **Enforcement:** Checked in `EquiMeshVault.deposit`; reverts with `ZeroSharesMinted()`.
- **Status:** **PROVEN ON EVM** (`test/contracts_invariants.test.js`, Invariant 11).

### Invariant 12 (INV-12): Reentrancy Protection
- **Rule:** Vault operations (deposit, withdraw, executeRebalance) are guarded against cross-function or reentrant execution.
- **Enforcement:** `nonReentrant` modifier on `deposit`, `withdraw`, and `executeRebalance`; reverts with `ReentrantCall()`.
- **Status:** **PROVEN ON EVM** (`test/contracts_invariants.test.js`, Invariant 12).

### Invariant 13 (INV-13): Fee-On-Transfer / Balance Deviation Rejection
- **Rule:** Tokens that charge transfer taxes or reduce balances in-flight are rejected upon deposit.
- **Enforcement:** Pre/post transfer balance checks in `EquiMeshVault.deposit` require `balAfter - balBefore == amount`; reverts with `"Fee-on-transfer tokens unsupported"`.
- **Status:** **PROVEN ON EVM** (`test/contracts_invariants.test.js`, Invariant 13).

### Invariant 14 (INV-14): Multi-Decimal Valuation & Accounting Consistency
- **Rule:** Multi-decimal assets (e.g. 6-decimal USDT/USDC vs 18-decimal bNVDA) are normalized to 18-decimal USD base without precision loss or decimal-shift bugs.
- **Enforcement:** `ReferencePriceOracle.getAssetValueUSD` divides by `10 ** tokenDecimals`; verified on EVM.
- **Status:** **PROVEN ON EVM** (`test/contracts_invariants.test.js`, Invariant 14).

### Invariant 15 (INV-15): Policy Gate View vs Execution Separation
- **Rule:** Read-only queries (`verifyTrade`, `verifyTradeUSD`) can be dry-run by any agent, monitoring tool, or user without advancing execution cooldown. Cooldown timestamp mutation is strictly restricted to the authorized vault during genuine execution.
- **Enforcement:** `onlyAuthorizedVault` modifier on `DeterministicPolicyGate.verifyAndRecordTrade`; external unauthorized calls revert with `UnauthorizedCaller()`.
- **Status:** **PROVEN ON EVM** (`test/contracts_invariants.test.js`, Invariant 15).
