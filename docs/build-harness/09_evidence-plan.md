# 09. Evidence Plan — EquiMesh

## Verifiable Evidence Artifacts

To convince an independent evaluator who does not trust this repository, the following artifacts are provided:

### 1. Invariant Verification Log
- **Location:** `test/policy_invariants.test.js`
- **Evidence:** Clean terminal run showing all 6 invariant suites passing with zero dependencies.
- **Reproducibility:** Run `node test/policy_invariants.test.js` from the repository root.

### 2. Developer Experience (DevEx) Report Telemetry
- **Location:** `dashboard/docs.html#devex-report`
- **Evidence:** Concrete benchmark table documenting time-to-first-call across Binance Web3 Wallet Aggregated API, BSC RPCs, BNB Agent Studio, and x402 headers.

### 3. Visual & Interactive Demo Console
- **Location:** `dashboard/index.html`
- **Evidence:** Full-fledged web dApp reflecting the reference technical engraving aesthetic with live interactive simulator sliders, terminal logs, and verifiable execution certificates.

### 4. Smart Contract Code
- **Location:** `contracts/DeterministicPolicyGate.sol` and `contracts/EquiMeshVault.sol`
- **Evidence:** Fully commented, standard Solidity smart contracts implementing fail-closed policy enforcement.
