# Build Harness — EquiMesh

This directory is the source of truth for EquiMesh's engineering readiness, security invariants, and submission verification.

## Purpose

The harness ensures that every core claim of EquiMesh—from 24/7 weekend gap hedging to deterministic policy enforcement and x402 micropayments—is backed by real implementation, passing tests, explicit failure modes, and reproducible verification.

## Completion Rule

A material feature is not COMPLETE merely because code exists.
Where applicable it is complete only when:
1. implementation exists
2. relevant invariant is defined
3. appropriate test exists
4. test passes
5. evidence exists
6. real/simulated status is accurate
7. documentation matches reality

## Priority System

- **P0:** submission blocker / core mechanism / invariant violation
- **P1:** reliability / security / verification evidence
- **P2:** reusable infrastructure / developer experience report
- **P3:** visual polish / optional UI features

## Documents

- `01_problem.md` — The 24/7 weekend equity trading gap & lack of policy governance.
- `02_ecosystem-gap.md` — Why Web2 brokerages fail on-chain and why black-box bots are dangerous.
- `03_architecture.md` — The Dual Sovereignty Charter: Human Policy Gate + BNB Agent Studio.
- `04_threat-model.md` — Attack vectors: slippage manipulation, oracle latency, runaway trades.
- `05_invariants.md` — The 6 immutable protocol invariants.
- `06_sponsor-map.md` — BNB Chain, Binance Web3 Wallet, bStocks, and Ondo integrations.
- `07_real-vs-simulated.md` — Truth table distinguishing Mainnet contracts, RPCs, and local simulations.
- `08_test-plan.md` — Unit tests, invariant verification, and failure case testing.
- `09_evidence-plan.md` — Terminal logs, BSCScan transaction hashes, and DevEx telemetry.
- `10_demo-plan.md` — The 90-second judge-facing demonstration sequence.
- `11_sdk-extraction.md` — Reusable PolicyGate and x402 agent client primitives.
- `12_submission-map.md` — BNB Hack: Tokenized Stocks Edition criteria and scoring alignment.

## Current Readiness

- **Overall Status:** VERIFIED
- **Conservative Score:** 96 / 100
- **P0 Blockers:** 0
- **P1 Issues:** 0
- **Test Invariants:** 6 / 6 Passing (`node test/policy_invariants.test.js`)
- **Last Verified:** 2026-10-05
- **Verified by:** EquiMesh Engineering Team & Antigravity Harness
