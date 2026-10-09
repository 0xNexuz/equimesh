/**
 * EquiMesh Autonomous Portfolio Accounting & Valuation Engine
 * Computes exact NAV, asset weights, and policy drift against thematic baskets.
 */

const THEMATIC_TARGETS = {
  tech: {
    name: "MAG-7 TECH",
    thresholdBps: 200, // 2.00%
    weights: {
      bNVDA: 0.45,
      bAAPL: 0.25,
      bTSLA: 0.15,
      "Ondo-USDY": 0.15
    }
  },
  semi: {
    name: "SEMI ALPHA",
    thresholdBps: 200, // 2.00%
    weights: {
      bNVDA: 0.60,
      bMSFT: 0.20,
      "Ondo-USDY": 0.20
    }
  },
  shield: {
    name: "WEEKEND SHIELD",
    thresholdBps: 200, // 2.00%
    weights: {
      "Ondo-USDY": 0.60,
      bNVDA: 0.25,
      bAAPL: 0.15
    }
  }
};

/**
 * Compute portfolio metrics given discrete asset balances and current prices.
 * @param {Object} balances { bNVDA: 250.0, bAAPL: 150.0, ... }
 * @param {Object} prices { bNVDA: 122.80, bAAPL: 228.40, ... }
 * @param {string} strategy 'tech' | 'semi' | 'shield'
 */
function calculatePortfolioState(balances, prices, strategy = "tech") {
  const target = THEMATIC_TARGETS[strategy] || THEMATIC_TARGETS.tech;
  const holdings = {};
  let totalNavUSD = 0;

  for (const [token, amount] of Object.entries(balances)) {
    const price = prices[token] || 0;
    const valueUSD = amount * price;
    holdings[token] = {
      amount,
      price,
      valueUSD
    };
    totalNavUSD += valueUSD;
  }

  let maxDriftBps = 0;
  const composition = [];

  for (const [token, targetWeight] of Object.entries(target.weights)) {
    const holding = holdings[token] || { amount: 0, price: prices[token] || 0, valueUSD: 0 };
    const currentWeight = totalNavUSD > 0 ? (holding.valueUSD / totalNavUSD) : 0;
    const driftBps = Math.round(Math.abs(currentWeight - targetWeight) * 10000);
    
    if (driftBps > maxDriftBps) {
      maxDriftBps = driftBps;
    }

    composition.push({
      token,
      amount: holding.amount,
      price: holding.price,
      valueUSD: holding.valueUSD,
      currentWeightPct: (currentWeight * 100).toFixed(2),
      targetWeightPct: (targetWeight * 100).toFixed(2),
      driftPct: ((currentWeight - targetWeight) * 100).toFixed(2),
      driftBps
    });
  }

  const rebalanceRequired = maxDriftBps >= target.thresholdBps;

  return {
    strategy: target.name,
    totalNavUSD: Number(totalNavUSD.toFixed(2)),
    maxDriftPct: (maxDriftBps / 100).toFixed(2),
    maxDriftBps,
    thresholdPct: (target.thresholdBps / 100).toFixed(2),
    thresholdBps: target.thresholdBps,
    rebalanceRequired,
    composition
  };
}

module.exports = {
  THEMATIC_TARGETS,
  calculatePortfolioState
};
