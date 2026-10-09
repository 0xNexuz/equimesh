// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IReferencePriceOracle {
    function getPriceUSD(address token) external view returns (uint256 price, uint8 decimals);
    function getAssetValueUSD(address token, uint256 amount) external view returns (uint256 valueUSD);
}

/**
 * @title ReferencePriceOracle
 * @notice Deterministic reference pricing oracle for tokenized stocks and RWA assets on BNB Smart Chain.
 * Returns asset prices normalized to 18 decimals USD ($1.00 = 1e18).
 */
contract ReferencePriceOracle is IReferencePriceOracle {
    address public immutable owner;

    struct TokenPrice {
        uint256 priceUSD; // 18-decimal fixed point (e.g. $122.80 = 122800000000000000000)
        uint8 tokenDecimals;
        bool isSet;
    }

    mapping(address => TokenPrice) public tokenPrices;

    event PriceUpdated(address indexed token, uint256 priceUSD, uint8 tokenDecimals);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Set reference price for a tokenized asset.
     * @param token Address of the token.
     * @param priceUSD Price in 18-decimal USD.
     * @param tokenDecimals Decimals of the token.
     */
    function setPriceUSD(address token, uint256 priceUSD, uint8 tokenDecimals) external onlyOwner {
        require(token != address(0), "Zero token address");
        require(priceUSD > 0, "Price must be > 0");
        tokenPrices[token] = TokenPrice(priceUSD, tokenDecimals, true);
        emit PriceUpdated(token, priceUSD, tokenDecimals);
    }

    /**
     * @notice Get reference price for a token.
     */
    function getPriceUSD(address token) external view override returns (uint256 price, uint8 decimals) {
        TokenPrice memory tp = tokenPrices[token];
        require(tp.isSet, "Price not configured for token");
        return (tp.priceUSD, tp.tokenDecimals);
    }

    /**
     * @notice Compute total USD value (in 18-decimal USD) for a given token amount.
     * Formula: (amount * priceUSD) / (10 ** tokenDecimals)
     */
    function getAssetValueUSD(address token, uint256 amount) public view override returns (uint256 valueUSD) {
        TokenPrice memory tp = tokenPrices[token];
        require(tp.isSet, "Price not configured for token");
        return (amount * tp.priceUSD) / (10 ** tp.tokenDecimals);
    }
}
