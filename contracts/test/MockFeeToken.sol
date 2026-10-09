// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MockERC20.sol";

/**
 * @title MockFeeToken
 * @notice Simulates a fee-on-transfer / tax token to prove vault rejection invariants.
 */
contract MockFeeToken is MockERC20 {
    uint256 public feeBps = 500; // 5.0% fee taken on transfer

    constructor(string memory name, string memory symbol, uint8 decimals)
        MockERC20(name, symbol, decimals) {}

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(to != address(0), "Transfer to zero");
        require(balanceOf[from] >= amount, "Insufficient balance");
        if (allowance[from][msg.sender] != type(uint256).max) {
            require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
            allowance[from][msg.sender] -= amount;
        }
        uint256 fee = (amount * feeBps) / 10000;
        uint256 netAmount = amount - fee;
        balanceOf[from] -= amount;
        balanceOf[to] += netAmount;
        balanceOf[address(0xdead)] += fee;
        emit Transfer(from, to, netAmount);
        return true;
    }
}
