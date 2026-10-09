/**
 * EquiMesh Autonomous Rebalancer Engine
 * Analyzes portfolio drift, enforces policy constraints, and builds bounded execution intents.
 */

const { calculatePortfolioState } = require("./portfolio");

const DEFAULT_POLICY = {
  maxSlippageBps: 100, // 1.00%
  maxSingleTradeUSD: 5000.0,
  cooldownSeconds: 900 // 15 min
};

/**
 * Formulate an optimal rebalancing trade intent based on portfolio state.
 * @param {Object} balances
 * @param {Object} prices
 * @param {string} strategy
 * @param {Object} policy
 */
function formulateRebalanceIntent(balances, prices, strategy = "tech", policy = DEFAULT_POLICY) {
  const state = calculatePortfolioState(balances, prices, strategy);
  
  if (!state.rebalanceRequired) {
    return {
      actionRequired: false,
      reason: `Drift ${state.maxDriftPct}% is within safe threshold ${state.thresholdPct}%.`
    };
  }

  // Find most overweight asset (to sell) and most underweight asset (to buy)
  let mostOverweight = null;
  let mostUnderweight = null;

  for (const item of state.composition) {
    const drift = parseFloat(item.driftPct);
    if (drift > 0 && (!mostOverweight || drift > parseFloat(mostOverweight.driftPct))) {
      mostOverweight = item;
    }
    if (drift < 0 && (!mostUnderweight || drift < parseFloat(mostUnderweight.driftPct))) {
      mostUnderweight = item;
    }
  }

  if (!mostOverweight || !mostUnderweight) {
    return {
      actionRequired: false,
      reason: "No actionable directional divergence detected."
    };
  }

  // Calculate USD value to rebalance (e.g. half the excess to avoid overshooting)
  const excessUSD = (parseFloat(mostOverweight.driftPct) / 100) * state.totalNavUSD * 0.5;
  const boundedTradeUSD = Math.min(excessUSD, policy.maxSingleTradeUSD);

  const priceIn = prices[mostOverweight.token];
  const priceOut = prices[mostUnderweight.token];

  if (!priceIn || !priceOut || priceIn <= 0 || priceOut <= 0) {
    throw new Error("Invalid asset pricing quote for rebalance intent");
  }

  const amountIn = Number((boundedTradeUSD / priceIn).toFixed(6));
  const expectedOut = Number((boundedTradeUSD / priceOut).toFixed(6));
  
  // Enforce Max Slippage Cap (100 bps / 1.0%)
  const minAmountOut = Number((expectedOut * (1 - (policy.maxSlippageBps / 10000))).toFixed(6));

  return {
    actionRequired: true,
    reason: `Target weight divergence: ${mostOverweight.token} is +${mostOverweight.driftPct}% overweight; rebalancing into ${mostUnderweight.token} (-${Math.abs(parseFloat(mostUnderweight.driftPct))}%)`,
    tokenIn: mostOverweight.token,
    tokenOut: mostUnderweight.token,
    tradeValueUSD: Number(boundedTradeUSD.toFixed(2)),
    amountIn,
    expectedOut,
    minAmountOut,
    maxSlippageBps: policy.maxSlippageBps,
    strategy: state.strategy
  };
}

module.exports = {
  DEFAULT_POLICY,
  formulateRebalanceIntent
};
