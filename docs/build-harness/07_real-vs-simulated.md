# 07. Real vs Simulated — EquiMesh Truth Matrix

In adherence to the Mag Build Harness honesty rule, this matrix documents the exact status, verification mechanism, and boundaries of every subsystem in EquiMesh:

| Subsystem | Environment | Status | Verification & Evidence |
|---|---|---|---|
| **Solidity Smart Contracts** | Solidity 0.8.20 / EVM | **REAL — EVM BYTECODE** | Compiled via `lib/compiler.js` (`evmVersion: paris`). 3 core contracts deployed and proven in `test/contracts_invariants.test.js`: `ReferencePriceOracle.sol`, `DeterministicPolicyGate.sol`, `EquiMeshVault.sol`. |
| **Proportional NAV Share Accounting** | Solidity EVM | **REAL — EVM BYTECODE** | Dynamic share minting on deposit and proportional multi-token payouts on withdrawal. Proves drain attack resistance on EVM. |
| **Deterministic Policy Gate** | Solidity EVM | **REAL — EVM BYTECODE** | Enforces 100 bps slippage cap, $5k trade ceiling, 15-minute cooldown, allowlist, and fail-closed circuit breaker. |
| **Adversarial & Concurrency Stress Engine** | Node.js Test Suite | **REAL — PROVEN** | 7 suites with 1,000 concurrent triggers, boundary tests, 10,000 flash-crash ticks, and poison vector tests in `test/stress_test.js`. |
| **x402 Micropayment Protocol** | Node.js & HTTP 402 | **REAL — COMPUTED** | Verified cryptographic settlement hash generator, nonce registry, and budget depletion tracker in `lib/x402.js`. |
| **BNB Chain Testnet Execution** | BSC Testnet (Chain ID 97) | **REAL — TESTNET** | Live wallet transactions on BSC Testnet generate authentic transactions verifiable on `https://testnet.bscscan.com`. |
| **Sandbox Portfolio Demonstrations** | Local In-Memory & EVM | **SIMULATED** | Pre-configured realistic weekend price divergence ($118.50 close vs $122.80 spot) with interactive slider. Generates cryptographic simulation certificates (`0xsim_...`). |
| **Mainnet Execution & User Funds** | BSC Mainnet (Chain ID 56) | **NOT IN PRODUCTION** | Explicitly scoped to Hackathon / Testnet verification. Zero real user funds or unverified mainnet contracts are used. |

### Rigorous Boundary & Evidence Rules
1. **Zero Fabricated Hashes:** Sandbox simulations are explicitly labeled `[SANDBOX PROOF]` or `[SIMULATED]`. No fake BSCScan mainnet links are ever generated for simulated actions.
2. **Honest Testnet Links:** When transactions are broadcasted via a connected Web3 wallet on BSC Testnet (Chain ID 97), authentic explorer links pointing to `testnet.bscscan.com` are provided.
3. **Reproducibility:** Anyone can verify the entire Solidity contract architecture and financial invariants locally with zero external network flakes by running `npm test`.
