# 08. Test Plan — EquiMesh

## Test Objectives
1. Verify that every core protocol invariant defined in `05_invariants.md` executes fail-closed.
2. Confirm that invalid trades (exceeding slippage, trade caps, or using unapproved tokens) revert with predictable error codes.
3. Validate that the emergency circuit breaker immediately rejects all agent activities.
4. Verify that x402 micropayments validate agent DIDs and produce valid cryptographic settlement proofs.

## Test Execution Command
```bash
node test/policy_invariants.test.js
```

## Test Coverage Matrix

| Test ID | Invariant Tested | Input Condition | Expected Result | Result |
|---|---|---|---|---|
| `TEST-01` | Invariant 1 (Slippage) | Slippage = 12 bps (<= 100 bps) | Trade Approved | **PASS** |
| `TEST-02` | Invariant 1 (Slippage) | Slippage = 150 bps (> 100 bps) | Revert: `SLIPPAGE_EXCEEDS_CAP` | **PASS** |
| `TEST-03` | Invariant 2 (Trade Ceiling) | Trade = $7,500 (> $5,000) | Revert: `TRADE_EXCEEDS_CAP` | **PASS** |
| `TEST-04` | Invariant 3 (Cooldown) | Second trade within 200s (< 900s) | Revert: `COOLDOWN_NOT_ELAPSED` | **PASS** |
| `TEST-05` | Invariant 4 (Allowlist) | Trade token = `SCAM_TOKEN` | Revert: `UNAUTHORIZED_TOKEN` | **PASS** |
| `TEST-06` | Invariant 5 (Circuit Breaker) | Circuit Breaker = Active | Revert: `CIRCUIT_BREAKER_ENGAGED` | **PASS** |
| `TEST-07` | Invariant 6 (x402 Micropay) | Valid DID & Signature | Settlement Proof Issued | **PASS** |
| `TEST-08` | Invariant 6 (x402 Micropay) | Invalid DID (`fake_agent_id`) | Revert: `INVALID_AGENT_ID` | **PASS** |

**Total Invariants Passed:** 6 / 6 (100%)
