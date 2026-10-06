# 11. SDK Extraction — EquiMesh

## Reusable Primitives Extracted from this Build

EquiMesh introduces two standalone primitives that any Web3 developer can adopt without using the full dApp:

### 1. `PolicyGate`: Reusable EVM Autonomous Authorization Layer
- **Source:** `contracts/DeterministicPolicyGate.sol`
- **Application:** Any AI agent executing on-chain transactions (whether in DeFi, gaming, or RWAs) can route transactions through `PolicyGate` to provide users with mathematically guaranteed protection against runaway losses, high slippage, and unauthorized token drains.
- **Portability:** Standalone Solidity contract compatible with any EVM network (BSC, opBNB, Ethereum).

### 2. `AgentX402`: Autonomous Micropayment Header Client
- **Source:** `test/policy_invariants.test.js` & `server.js`
- **Application:** Enables autonomous agents to negotiate HTTP 402 micro-settlements over decentralized data APIs, attaching agent DIDs and verifiable cryptographic payment signatures.
- **Portability:** Zero-dependency Node.js / TypeScript module suitable for publishing as `@bnb-chain/agent-x402`.
