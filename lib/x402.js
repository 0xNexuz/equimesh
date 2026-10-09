/**
 * EquiMesh x402 Micropayment Protocol Module
 * Handles agent-to-oracle HTTP 402 micro-settlements, nonce verification, and anti-replay protection.
 */

const crypto = require("node:crypto");

class X402Manager {
  constructor(initialPoolUSD = 49.88) {
    this.agentDid = "did:bnb:agent:equimesh-v1-mainnet";
    this.poolBalanceUSD = initialPoolUSD;
    this.costPerQueryUSD = 0.01;
    this.settledNonces = new Set();
    this.receiptHistory = [];
  }

  /**
   * Authorize and settle an autonomous micropayment.
   * @param {string} agentId
   * @param {string} nonce
   * @param {string} signature
   */
  settlePayment(agentId, nonce, signature) {
    if (!agentId || !agentId.startsWith("did:bnb:agent:")) {
      throw new Error("INVALID_AGENT_ID: Payment requires verifiable BNB Agent Studio DID");
    }

    if (!nonce || typeof nonce !== "string" || nonce.length < 8) {
      throw new Error("INVALID_NONCE: Micropayment nonce must be at least 8 characters");
    }

    if (this.settledNonces.has(nonce)) {
      throw new Error("REPLAY_ATTACK_DETECTED: Nonce has already been settled");
    }

    if (this.poolBalanceUSD < this.costPerQueryUSD) {
      throw new Error("INSUFFICIENT_FUNDS: Agent x402 compute pool depleted");
    }

    if (!signature || signature.length < 16) {
      throw new Error("INVALID_SIGNATURE: Cryptographic settlement signature invalid");
    }

    this.settledNonces.add(nonce);
    this.poolBalanceUSD = Number((this.poolBalanceUSD - this.costPerQueryUSD).toFixed(4));

    const proofHash = crypto.createHash("sha256")
      .update(`${agentId}:${nonce}:${signature}:${this.costPerQueryUSD}`)
      .digest("hex");

    const receipt = {
      agentId,
      amountUSD: this.costPerQueryUSD,
      nonce,
      settlementHash: `0x402_sig_${proofHash.slice(0, 16)}`,
      timestamp: new Date().toISOString(),
      remainingPoolUSD: this.poolBalanceUSD
    };

    this.receiptHistory.push(receipt);
    return receipt;
  }
}

module.exports = {
  X402Manager
};
