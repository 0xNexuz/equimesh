# 04. Threat Model — EquiMesh

## Assets Under Protection
1. **Depositor Capital:** ERC-20 token balances in `EquiMeshVault.sol` (bStocks NVDA/AAPL/TSLA/MSFT, Ondo USDY, USDT).
2. **Policy Invariants:** On-chain rules set by vault owners (max trade limits, slippage caps, cooldown intervals).
3. **Agent Compute/Micropayment Balance:** x402 USD treasury used by the agent to acquire off-chain oracle feeds.

## Threat Actors
- **MEV Bots & Sandwich Attackers:** Exploiting large rebalance transactions on BSC DEX pools.
- **Compromised Agent Key / Rogue AI Logic:** Rogue agent attempting to drain vault funds or swap into illicit tokens.
- **Oracle Manipulation / Stale Quotes:** Artificially skewing prices or feeding stale historical quotes to force disadvantageous rebalances.
- **Malicious Routers & Calldata Tampering:** Diverting swapped funds to external addresses or calling malicious contracts.
- **Reentrancy & Tax Token Attackers:** Reentering during callbacks or exploiting fee-on-transfer discrepancies.
- **Share Inflation & Donation Attackers:** Minting 0 shares or manipulating NAV ratios with dust balances.

## Mitigations & Security Guarantees

| Threat Vector | Mitigation Mechanism | Verification Test |
|---|---|---|
| **Sandwich Attack / Slippage** | Max Slippage Cap (100 bps) verified both in Binance Web3 Wallet simulation and on-chain by `DeterministicPolicyGate`. | `INV-05` (100 bps Cap) |
| **Rogue Agent Drain** | Single Trade Ceiling ($5,000 max) + Temporal Cooldown (15 min) prevents rapid fund draining. | `INV-04` & `INV-07` |
| **Phishing / Scam Tokens** | Token Allowlist strictly limits trade destinations to audited bStocks & Ondo contracts. | `INV-03` (Token Allowlist) |
| **Emergency Market Crisis** | Human Emergency Circuit Breaker: instantly fails-closed, revoking all agent execution rights. | `INV-02` (Circuit Breaker) |
| **Unapproved Routers** | Router Allowlist (`approvedRouters`): Only registered, audited DEX routers can be invoked. | `INV-08` (Router Allowlist) |
| **Calldata Diversion** | Strict calldata decoding: Parameter matching and vault recipient binding (`recipient == address(this)`). | `INV-09` (Calldata Binding) |
| **Oracle Staleness / Spoofing** | Fail-Closed Stale Check (24h default) + Sanity Bounds ($0.0001 to $10,000,000). | `INV-10` (Oracle Freshness) |
| **Zero-Share / Inflation Attack** | Minimum initial shares (`MIN_INITIAL_SHARES = 1000`) + strict `ZeroSharesMinted` check. | `INV-11` (Inflation Guard) |
| **Reentrancy Exploitation** | Institutional `nonReentrant` guard on `deposit`, `withdraw`, and `executeRebalance`. | `INV-12` (Reentrancy Guard) |
| **Fee-On-Transfer Token Theft** | Pre/post balance delta checks on `deposit`; balance divergence reverts fail-closed. | `INV-13` (Fee Token Reject) |
| **Decimal Precision Drift** | Oracle divides by `10 ** tokenDecimals`, preserving exact 18-decimal USD base across all assets. | `INV-14` (Multi-Decimal) |
| **Sybil Oracle Attacks** | x402 Payment Protocol requires valid cryptographic signature and DID verification before accepting feeds. | `STRESS-05` (x402 Verification) |

## Non-Guarantees
- EquiMesh does not guarantee market profits; equity prices may decline due to broader macroeconomic shifts.
- EquiMesh spot products do not offer leverage or perpetual margin.
