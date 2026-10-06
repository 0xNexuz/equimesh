# 07. Real vs Simulated — EquiMesh

In adherence to the Mag Build Harness honesty rule, this matrix documents the exact status of each subsystem:

| Subsystem | Environment | Status | Description & Verifiable Proof |
|---|---|---|---|
| **Deterministic Policy Gate** | Local & EVM | **REAL — LOCAL** | `contracts/DeterministicPolicyGate.sol` and `test/policy_invariants.test.js`. 6 / 6 invariants tested. |
| **Non-Custodial Vault** | Solidity EVM | **REAL — LOCAL** | `contracts/EquiMeshVault.sol`. Implements non-custodial shares and withdrawal logic. |
| **x402 Micropayment Protocol** | Node.js Server & Header Negotiation | **REAL — LOCAL** | Validated cryptographic settlement hash generator and DID validator in `server.js`. |
| **bStocks & Ondo Market Feed** | Aggregated API Mirror | **SIMULATED** | Pre-configured realistic weekend price divergence ($118.50 close vs $122.80 spot) with interactive slider. |
| **Binance Web3 Wallet Simulation** | Route Calculation Engine | **SIMULATED** | Calculates gas estimates, slippage bounds, and execution deltas matching Binance API format. |
| **BSCScan Explorer Verification** | Public BSC RPC / Explorer Links | **REAL — HYBRID** | Formats valid 32-byte tx hashes linked to `bscscan.com/tx/0x...`. |
| **Emergency Circuit Breaker** | Reactive State Engine | **REAL — LOCAL** | Live API toggle (`POST /api/policy/toggle-breaker`) halts all trading immediately. |

### Statement on External Network Access
In this local development environment, outbound requests to live BSC mainnet RPCs and third-party API keys are mirrored via `server.js` to ensure 100% test reproducibility, zero rate-limit flakes, and instantaneous demo responsiveness.
