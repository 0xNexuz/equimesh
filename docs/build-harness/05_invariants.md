# 05. Invariants — EquiMesh

These 6 invariants must hold true across all operations. They are programmatically audited by `test/policy_invariants.test.js`.

### Invariant 1: Max Slippage Cap
- **Rule:** No trade may execute if the expected price impact / slippage exceeds the configured threshold (default: 100 bps / 1.0%).
- **Enforcement:** Enforced in Binance Web3 Wallet simulation pre-flight and checked on-chain in `DeterministicPolicyGate.sol`.
- **Status:** VERIFIED.

### Invariant 2: Single Trade Size Ceiling
- **Rule:** An individual rebalance transaction cannot exceed `maxSingleTradeUSD` (default: $5,000 USD).
- **Enforcement:** Smart contract reverts with `TradeExceedsMaximumSize`.
- **Status:** VERIFIED.

### Invariant 3: Temporal Cooldown (Rate Limiting)
- **Rule:** Consecutive rebalance transactions must be separated by at least `cooldownSeconds` (default: 900 seconds / 15 minutes).
- **Enforcement:** Smart contract checks `block.timestamp >= lastExecutionTimestamp + cooldownSeconds`.
- **Status:** VERIFIED.

### Invariant 4: Token Allowlist
- **Rule:** The vault may only hold or trade tokens explicitly designated by the owner (bNVDA, bAAPL, bTSLA, bMSFT, Ondo-USDY, USDT).
- **Enforcement:** Reverts with `TokenNotAllowlisted`.
- **Status:** VERIFIED.

### Invariant 5: Emergency Circuit Breaker (Fail-Closed)
- **Rule:** When the human circuit breaker is engaged, ALL agent execution is halted unconditionally. No trades may execute.
- **Enforcement:** Checked first in `DeterministicPolicyGate.verifyTrade()`; reverts with `CircuitBreakerEngaged`.
- **Status:** VERIFIED.

### Invariant 6: x402 Micropayment Authenticity
- **Rule:** Off-chain intelligence feeds require valid cryptographic settlement proofs and verified agent DIDs before ingestion.
- **Enforcement:** Verified via `verifyX402Settlement()`.
- **Status:** VERIFIED.
