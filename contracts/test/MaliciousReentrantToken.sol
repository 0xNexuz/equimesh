// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MockERC20.sol";
import "../EquiMeshVault.sol";

/**
 * @title MaliciousReentrantToken
 * @notice An ERC-20 token that attempts to re-enter EquiMeshVault during transfer/transferFrom.
 */
contract MaliciousReentrantToken is MockERC20 {
    EquiMeshVault public targetVault;
    bool public attackTriggered;

    constructor(string memory name, string memory symbol, uint8 decimals)
        MockERC20(name, symbol, decimals) {}

    function setTargetVault(address payable _vault) external {
        targetVault = EquiMeshVault(_vault);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (!attackTriggered && address(targetVault) != address(0)) {
            attackTriggered = true;
            // Attempt to re-enter deposit while in the middle of transferFrom
            targetVault.deposit(address(this), amount);
        }
        return super.transferFrom(from, to, amount);
    }
}
