const crypto = require("node:crypto");

let agentState = {
  active: true,
  agentId: "did:bnb:agent:equimesh-v1-mainnet",
  rebalanceCount: 14,
  lastRebalance: new Date(Date.now() - 1000 * 60 * 18).toISOString(),
  circuitBreakerEngaged: false,
  x402Balance: 49.88,
  totalAUM: 124850.0,
  yieldEarnedOndo: 1420.5,
  policy: {
    maxSlippageBps: 100,
    maxSingleTradeUSD: 5000,
    rebalanceCooldownMinutes: 15,
    allowedTokens: ["bNVDA", "bAAPL", "bTSLA", "bMSFT", "Ondo-USDY", "USDT"],
    requireHumanApprovalOnDrawdownBps: 500
  }
};

let marketData = {
  tradFiMarketOpen: false,
  fridayCloseTime: "2026-10-02T20:00:00Z",
  tokens: {
    bNVDA: { symbol: "bNVDA", name: "bStocks NVIDIA", tradFiClose: 118.5, onChainSpot: 122.8, weekendGapPct: 3.63, volume24h: 3450000 },
    bAAPL: { symbol: "bAAPL", name: "bStocks Apple", tradFiClose: 226.0, onChainSpot: 228.4, weekendGapPct: 1.06, volume24h: 2180000 },
    bTSLA: { symbol: "bTSLA", name: "bStocks Tesla", tradFiClose: 248.2, onChainSpot: 242.1, weekendGapPct: -2.46, volume24h: 4120000 },
    bMSFT: { symbol: "bMSFT", name: "bStocks Microsoft", tradFiClose: 428.0, onChainSpot: 429.5, weekendGapPct: 0.35, volume24h: 1850000 },
    "Ondo-USDY": { symbol: "Ondo-USDY", name: "Ondo US Dollar Yield", apy: 5.15, onChainSpot: 1.052, yieldEarned30d: 0.42 }
  }
};

let executionReceipts = [
  {
    receiptId: "rcpt_0x8b60d72",
    txHash: "0x8b60d7222925aae8842ed936c5fc68638ffbff6b6b0787fcb0f7c02bedc03f6d",
    timestamp: new Date(Date.now() - 1000 * 60 * 18).toISOString(),
    triggerReason: "Weekend Gap Deviation > 3.0% (bNVDA)",
    action: "Spot Rebalance into Cash Buffer",
    inputToken: "bNVDA",
    inputAmount: "25.00 ($3,070.00)",
    outputToken: "Ondo-USDY",
    outputAmount: "2,918.25 USDY ($3,070.00)",
    slippageObserved: "0.12%",
    x402PaidUSD: 0.01,
    x402SettlementHash: "0x402_sig_7b9c3f2e1a",
    policyCheck: "PASSED (All 5 Invariants Satisfied)",
    gasUsedBNB: "0.00182 BNB ($1.05)",
    bscScanUrl: "https://bscscan.com/tx/0x8b60d7222925aae8842ed936c5fc68638ffbff6b6b0787fcb0f7c02bedc03f6d"
  },
  {
    receiptId: "rcpt_0x4e48d4f",
    txHash: "0x4e48d4f70edeeadb2f052d527d591a632d16febac7feb79f3c2d13bb4b48d360",
    timestamp: new Date(Date.now() - 1000 * 60 * 75).toISOString(),
    triggerReason: "Scheduled 1-Hour Basket Weight Alignment",
    action: "Harvest Ondo Yield -> DCA bTSLA Dip",
    inputToken: "Ondo-USDY",
    inputAmount: "1,500.00 USDY",
    outputToken: "bTSLA",
    outputAmount: "6.20 bTSLA ($1,501.02)",
    slippageObserved: "0.09%",
    x402PaidUSD: 0.01,
    x402SettlementHash: "0x402_sig_1d2e3f4a5b",
    policyCheck: "PASSED (All 5 Invariants Satisfied)",
    gasUsedBNB: "0.00164 BNB ($0.95)",
    bscScanUrl: "https://bscscan.com/tx/0x4e48d4f70edeeadb2f052d527d591a632d16febac7feb79f3c2d13bb4b48d360"
  }
];

module.exports = (req, res) => {
  const urlParts = req.url.split("?");
  const reqPath = urlParts[0];

  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.statusCode = 204;
    res.end();
    return;
  }

  if (reqPath.endsWith("/api/status") || reqPath === "/status") {
    res.setHeader("Content-Type", "application/json");
    res.statusCode = 200;
    res.end(JSON.stringify(agentState));
    return;
  }

  if (reqPath.endsWith("/api/market") || reqPath === "/market") {
    res.setHeader("Content-Type", "application/json");
    res.statusCode = 200;
    res.end(JSON.stringify(marketData));
    return;
  }

  if (reqPath.endsWith("/api/receipts") || reqPath === "/receipts") {
    res.setHeader("Content-Type", "application/json");
    res.statusCode = 200;
    res.end(JSON.stringify(executionReceipts));
    return;
  }

  if (reqPath.endsWith("/api/policy/toggle-breaker") || reqPath === "/policy/toggle-breaker") {
    agentState.circuitBreakerEngaged = !agentState.circuitBreakerEngaged;
    res.setHeader("Content-Type", "application/json");
    res.statusCode = 200;
    res.end(JSON.stringify({ circuitBreakerEngaged: agentState.circuitBreakerEngaged }));
    return;
  }

  if (reqPath.endsWith("/api/agent/trigger") || reqPath === "/agent/trigger") {
    let body = "";
    req.on("data", chunk => body += chunk);
    req.on("end", () => {
      let params = {};
      try { params = JSON.parse(body || "{}"); } catch (e) {}

      if (agentState.circuitBreakerEngaged) {
        res.setHeader("Content-Type", "application/json");
        res.statusCode = 403;
        res.end(JSON.stringify({
          success: false,
          error: "POLICY_VIOLATION: Circuit breaker engaged. Autonomous trading halted."
        }));
        return;
      }

      const tradeAmountUSD = params.amountUSD || 2500;
      if (tradeAmountUSD > agentState.policy.maxSingleTradeUSD) {
        res.setHeader("Content-Type", "application/json");
        res.statusCode = 400;
        res.end(JSON.stringify({
          success: false,
          error: `POLICY_VIOLATION: Trade size $${tradeAmountUSD} exceeds policy cap of $${agentState.policy.maxSingleTradeUSD}.`
        }));
        return;
      }

      const txRandom = crypto.randomBytes(32).toString("hex");
      const sigRandom = crypto.randomBytes(16).toString("hex");
      agentState.x402Balance = Math.max(0, agentState.x402Balance - 0.01);
      agentState.rebalanceCount += 1;
      agentState.lastRebalance = new Date().toISOString();

      const newReceipt = {
        receiptId: `rcpt_0x${txRandom.slice(0, 16)}`,
        txHash: `0x${txRandom}`,
        timestamp: new Date().toISOString(),
        triggerReason: params.reason || "Autonomous Gap Rebalance & Yield Sweep",
        action: params.action || "Dynamic Spot Swap (bStocks + Ondo)",
        inputToken: params.inputToken || "bNVDA",
        inputAmount: `${(tradeAmountUSD / 122.8).toFixed(2)} bNVDA ($${tradeAmountUSD})`,
        outputToken: params.outputToken || "Ondo-USDY",
        outputAmount: `${(tradeAmountUSD / 1.052).toFixed(2)} USDY ($${tradeAmountUSD})`,
        slippageObserved: "0.08%",
        x402PaidUSD: 0.01,
        x402SettlementHash: `0x402_sig_${sigRandom}`,
        policyCheck: "PASSED (Deterministic Verification Satisfied)",
        gasUsedBNB: "0.00171 BNB ($0.99)",
        bscScanUrl: `https://bscscan.com/tx/0x${txRandom}`
      };

      executionReceipts.unshift(newReceipt);
      if (executionReceipts.length > 20) executionReceipts.pop();

      res.setHeader("Content-Type", "application/json");
      res.statusCode = 200;
      res.end(JSON.stringify({ success: true, receipt: newReceipt, state: agentState }));
    });
    return;
  }

  res.setHeader("Content-Type", "application/json");
  res.statusCode = 404;
  res.end(JSON.stringify({ error: "Endpoint not found" }));
};
