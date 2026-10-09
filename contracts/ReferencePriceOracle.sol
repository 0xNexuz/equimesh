// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IReferencePriceOracle {
    function getPriceUSD(address token) external view returns (uint256 price, uint8 decimals);
    function getAssetValueUSD(address token, uint256 amount) external view returns (uint256 valueUSD);
    function isPriceFresh(address token) external view returns (bool);
}

/**
 * @title ReferencePriceOracle
 * @notice Deterministic reference pricing oracle for tokenized stocks and RWA assets on BNB Smart Chain.
 * Returns asset prices normalized to 18 decimals USD ($1.00 = 1e18) with fail-closed staleness checks.
 */
contract ReferencePriceOracle is IReferencePriceOracle {
    address public immutable owner;

    struct TokenPrice {
        uint256 priceUSD; // 18-decimal fixed point (e.g. $122.80 = 122800000000000000000)
        uint8 tokenDecimals;
        uint256 updatedAt;
        bool isSet;
    }

    uint256 public maxStaleness = 24 hours; // 86,400 seconds default
    uint256 public minPriceUSD = 1e14;      // $0.0001 minimum sanity bound (18 decimals)
    uint256 public maxPriceUSD = 10_000_000 * 1e18; // $10,000,000 max sanity bound

    mapping(address => TokenPrice) public tokenPrices;

    event PriceUpdated(address indexed token, uint256 priceUSD, uint8 tokenDecimals, uint256 timestamp);
    event MaxStalenessUpdated(uint256 newMaxStaleness);
    event PriceBoundsUpdated(uint256 minPriceUSD, uint256 maxPriceUSD);

    error ZeroAddress();
    error PriceOutOfBounds(uint256 price, uint256 min, uint256 max);
    error PriceNotConfigured(address token);
    error OraclePriceStale(address token, uint256 updatedAt, uint256 blockTimestamp);
    error InvalidDecimals();

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setMaxStaleness(uint256 _maxStaleness) external onlyOwner {
        require(_maxStaleness >= 60, "Staleness threshold too low");
        maxStaleness = _maxStaleness;
        emit MaxStalenessUpdated(_maxStaleness);
    }

    function setPriceBounds(uint256 _minPriceUSD, uint256 _maxPriceUSD) external onlyOwner {
        require(_minPriceUSD > 0 && _maxPriceUSD > _minPriceUSD, "Invalid bounds");
        minPriceUSD = _minPriceUSD;
        maxPriceUSD = _maxPriceUSD;
        emit PriceBoundsUpdated(_minPriceUSD, _maxPriceUSD);
    }

    /**
     * @notice Set reference price for a tokenized asset.
     * @param token Address of the token.
     * @param priceUSD Price in 18-decimal USD.
     * @param tokenDecimals Decimals of the token.
     */
    function setPriceUSD(address token, uint256 priceUSD, uint8 tokenDecimals) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (tokenDecimals > 36) revert InvalidDecimals();
        if (priceUSD < minPriceUSD || priceUSD > maxPriceUSD) {
            revert PriceOutOfBounds(priceUSD, minPriceUSD, maxPriceUSD);
        }
        tokenPrices[token] = TokenPrice(priceUSD, tokenDecimals, block.timestamp, true);
        emit PriceUpdated(token, priceUSD, tokenDecimals, block.timestamp);
    }

    /**
     * @notice Check whether a token price is configured and not stale.
     */
    function isPriceFresh(address token) public view override returns (bool) {
        TokenPrice memory tp = tokenPrices[token];
        if (!tp.isSet) return false;
        if (block.timestamp > tp.updatedAt + maxStaleness) return false;
        if (tp.priceUSD < minPriceUSD || tp.priceUSD > maxPriceUSD) return false;
        return true;
    }

    /**
     * @notice Get reference price for a token, failing closed if stale.
     */
    function getPriceUSD(address token) external view override returns (uint256 price, uint8 decimals) {
        TokenPrice memory tp = tokenPrices[token];
        if (!tp.isSet) revert PriceNotConfigured(token);
        if (block.timestamp > tp.updatedAt + maxStaleness) {
            revert OraclePriceStale(token, tp.updatedAt, block.timestamp);
        }
        if (tp.priceUSD < minPriceUSD || tp.priceUSD > maxPriceUSD) {
            revert PriceOutOfBounds(tp.priceUSD, minPriceUSD, maxPriceUSD);
        }
        return (tp.priceUSD, tp.tokenDecimals);
    }

    /**
     * @notice Compute total USD value (in 18-decimal USD) for a given token amount.
     * Formula: (amount * priceUSD) / (10 ** tokenDecimals)
     */
    function getAssetValueUSD(address token, uint256 amount) public view override returns (uint256 valueUSD) {
        TokenPrice memory tp = tokenPrices[token];
        if (!tp.isSet) revert PriceNotConfigured(token);
        if (block.timestamp > tp.updatedAt + maxStaleness) {
            revert OraclePriceStale(token, tp.updatedAt, block.timestamp);
        }
        if (tp.priceUSD < minPriceUSD || tp.priceUSD > maxPriceUSD) {
            revert PriceOutOfBounds(tp.priceUSD, minPriceUSD, maxPriceUSD);
        }
        return (amount * tp.priceUSD) / (10 ** tp.tokenDecimals);
    }
}
