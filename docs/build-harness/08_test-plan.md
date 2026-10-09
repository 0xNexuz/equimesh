# 08. Test Plan & Invariant Proof Harness — EquiMesh

## Test Objectives
1. Prove all 7 core Solidity smart contract security invariants on EVM bytecode (`contracts/ReferencePriceOracle.sol`, `contracts/DeterministicPolicyGate.sol`, `contracts/EquiMeshVault.sol`).
2. Stress test the autonomous execution engine against 1,000 concurrent race conditions, boundary values, poisoned payloads, and 10,000 flash-crash market ticks.
3. Validate anti-replay protection and budget depletion for x402 micropayments.
4. Establish 100% reproducible local verification with zero external dependencies.

## Test Commands
```bash
# 1. Run the full verification suite (EVM Contracts + Adversarial Stress Tests):
npm test

# 2. Or run individual suites:
npm run test:contracts  # Local EVM Solidity compilation & invariant proofs
npm run test:stress     # High-concurrency & black swan adversarial stress suite
npm run test:policy     # Fast standalone policy invariant verification
```

## Test Coverage Matrix

### Part A: Real EVM Smart Contract Invariant Suite (`test/contracts_invariants.test.js`)

| Invariant ID | Security Invariant | EVM Trigger Condition | Expected Result | Status |
|---|---|---|---|---|
| `INV-01` | Proportional Share Accounting | Attacker deposits $10, tries to withdraw $500 | Revert: `InsufficientShares` | **PASS** |
| `INV-02` | Emergency Circuit Breaker | Kill switch active; trade attempted | Revert: `CircuitBreakerEngaged` (Fail-Closed) | **PASS** |
| `INV-03` | Token Allowlist Enforcement | Rebalance proposed with fake token | Revert: `TokenNotAllowlisted` | **PASS** |
| `INV-04` | Single Trade Size Ceiling | Trade size = $6,140 (> $5,000 cap) | Revert: `TradeExceedsMaximumSize` | **PASS** |
| `INV-05` | Max Slippage Bounds (100 bps) | Proposed slippage = 5.7% (> 1.0% cap) | Revert: `SlippageExceedsCap` | **PASS** |
| `INV-06` | Balance Delta Reconciliation | Real swap executed on EVM router | Pre/Post balance deltas exactly reconciled | **PASS** |
| `INV-07` | Temporal Rate Limiting | Rapid trade within 900s cooldown | Revert: `CooldownNotElapsed`; passes at 901s | **PASS** |

### Part B: Adversarial & High-Concurrency Suite (`test/stress_test.js`)

| Suite ID | Attack / Stress Vector | Workload Scale | Invariant Protected | Status |
|---|---|---|---|---|
| `STRESS-01` | High Concurrency Race Condition | 1,000 simultaneous triggers | Cooldown Mutex (1 pass, 999 rejected) | **PASS** |
| `STRESS-02` | Exact Boundary Precision | 99 bps vs 100 bps vs 101 bps | Slippage & $5k Trade Size Caps | **PASS** |
| `STRESS-03` | Malicious / Poisoned Payloads | NaN, Infinity, SQL injection, negative | Input validation & zero crashes | **PASS** |
| `STRESS-04` | Black Swan Flash Crash | 10,000 randomized volatility ticks | Slippage filters out volatile spikes | **PASS** |
| `STRESS-05` | x402 Replay & Budget Depletion | Replay identical nonce, exhaust pool | Anti-replay & graceful budget halt | **PASS** |
| `STRESS-06` | Kill Switch In-Flight Load | 2,000 concurrent calls under breaker | 2,000 / 2,000 dropped fail-closed | **PASS** |
| `STRESS-07` | Dual Network Isolation | 500 interleaved transactions | 100% Mainnet / Testnet state isolation | **PASS** |

**Total Invariants & Stress Suites Passed:** 14 / 14 (100% Pass Rate, 0 Failures).
