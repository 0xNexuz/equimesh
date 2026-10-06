# 04. Threat Model — EquiMesh

## Assets Under Protection
1. **Depositor Capital:** ERC-20 token balances in `EquiMeshVault.sol` (bStocks NVDA/AAPL/TSLA/MSFT, Ondo USDY, USDT).
2. **Policy Invariants:** On-chain rules set by vault owners (max trade limits, slippage caps, cooldown intervals).
3. **Agent Compute/Micropayment Balance:** x402 USD treasury used by the agent to acquire off-chain oracle feeds.

## Threat Actors
- **MEV Bots & Sandwich Attackers:** Exploiting large rebalance transactions on BSC DEX pools.
- **Compromised Agent Key / Malicious Agent Logic:** Rogue agent attempting to drain vault funds or swap into illicit tokens.
- **Oracle Manipulation / Flash Crashes:** Artificially skewing weekend prices to force disadvantageous rebalances.
- **High Slippage / Illiquid Pools:** Swapping during periods of thin weekend liquidity.

## Mitigations & Security Guarantees

| Threat Vector | Mitigation Mechanism | Verification Test |
|---|---|---|
| **Sandwich Attack / Slippage** | Max Slippage Cap (100 bps) verified both in Binance Web3 Wallet simulation and on-chain by `DeterministicPolicyGate`. | `Test 1: Slippage Cap` |
| **Rogue Agent Drain** | Single Trade Ceiling ($5,000 max) + Temporal Cooldown (15 min) prevents rapid fund draining. | `Test 2 & Test 3` |
| **Phishing / Scam Tokens** | Token Allowlist strictly limits trade destinations to audited bStocks & Ondo contracts. | `Test 4: Token Allowlist` |
| **Emergency Market Crisis** | Human Emergency Circuit Breaker: instantly fails-closed, revoking all agent execution rights. | `Test 5: Circuit Breaker` |
| **Sybil Oracle Attacks** | x402 Payment Protocol requires valid cryptographic signature and DID verification before accepting feeds. | `Test 6: x402 Verification` |

## Non-Guarantees
- EquiMesh does not guarantee market profits; equity prices may decline due to broader macroeconomic shifts.
- EquiMesh spot products do not offer leverage or perpetual margin.
