# 05. Invariants — EquiMesh

These 7 core on-chain and financial invariants are mathematically enforced and proven by `test/contracts_invariants.test.js` against compiled Solidity 0.8.20 bytecode executing on local EVM.

### Invariant 1 (INV-01): Proportional Share Accounting & Non-Custodial Multi-Asset NAV
- **Rule:** Depositors receive vault shares proportional to the total USD Net Asset Value (NAV) of the basket at the moment of deposit. On withdrawal, users burn shares to redeem an exact proportional slice of every underlying asset held in the vault. No depositor can withdraw more value than their share ratio permits.
- **Enforcement:** Enforced in `EquiMeshVault.deposit` and `EquiMeshVault.withdraw`. Completely eliminates 1:1 token drain attacks.
- **Status:** **PROVEN ON EVM** (`test/contracts_invariants.test.js`, Invariant 1).

### Invariant 2 (INV-02): Emergency Human Circuit Breaker (Fail-Closed)
- **Rule:** When the emergency kill switch is engaged, ALL autonomous execution paths halt immediately and fail-closed. No swaps, trades, or rebalances can execute under any circumstances.
- **Enforcement:** Checked first in `DeterministicPolicyGate.verifyAndRecordTrade`; reverts unconditionally with `CircuitBreakerEngaged()`.
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
