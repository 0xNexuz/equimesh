# 03. Architecture — EquiMesh

## System Architecture Overview

EquiMesh decouples policy authorization from autonomous execution through a layered three-tier architecture:

```
+-----------------------------------------------------------------------------------+
|                            TIER 1: USER CONSOLE (WEB)                             |
|  - Thematic Basket Builder (bStocks: NVDA, AAPL, TSLA + Ondo USDY)               |
|  - Deterministic Policy Charter Editor (Slippage bounds, trade size limits)       |
|  - Emergency Human Circuit Breaker (Fail-closed toggle)                          |
|  - Verifiable Receipt Inspector & Weekend Gap Simulation                         |
+-----------------------------------------------------------------------------------+
                                        | (Authorizes Mandate)
                                        v
+-----------------------------------------------------------------------------------+
|                     TIER 2: BNB AGENT STUDIO & RUNTIME LAYER                      |
|  - Agent Identity: did:bnb:agent:equimesh-v1-mainnet                              |
|  - Trigger Engine: Evaluates basket drift & weekend price deviation               |
|  - x402 Micropayment Client: Autonomous payment ($0.01) for oracle intelligence   |
|  - Transaction Simulation: Binance Web3 Wallet Aggregated API pre-flight check    |
+-----------------------------------------------------------------------------------+
                                        | (Executes Spot Rebalance)
                                        v
+-----------------------------------------------------------------------------------+
|                     TIER 3: ON-CHAIN SMART CONTRACTS (BSC)                        |
|  - DeterministicPolicyGate.sol: Enforces 5 hard invariants before allowing swaps |
|  - EquiMeshVault.sol: Non-custodial ERC-4626 basket vault holding user assets     |
|  - Aggregated Liquidity Router: Spot swaps across BSC Mainnet pools               |
+-----------------------------------------------------------------------------------+
```

## Key Interfaces & Protocols

1. **DeterministicPolicyGate.sol:**
   - Validates `verifyTrade(tokenIn, tokenOut, amountInUSD, slippageBps)` on-chain.
   - Halts immediately if the emergency circuit breaker is active.
2. **BNB Agent Studio Manifest:**
   - Defines agent capabilities, permissions, and tool endpoints.
3. **x402 Micropayment Protocol:**
   - Provides pay-per-call access to real-time off-chain sentiment feeds and oracle data.
