// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @title xbtcProxy
 * @author xBTC Development Team
 * @notice Transparent upgradeable proxy for Cross-Chain Bitcoin (xBTC) Token
 * @dev This contract serves as a proxy for the xBTC implementation, enabling
 *      upgrades while maintaining state and providing a consistent interface.
 *      Uses OpenZeppelin's battle-tested TransparentUpgradeableProxy pattern.
 * 
 * Key Features:
 * - Transparent proxy pattern separating admin and user interactions
 * - Secure upgrade mechanism controlled by proxy admin
 * - Gas-optimized deployment for multi-chain consistency
 * - Immutable proxy address across all supported chains
 */
contract xbtcProxy is TransparentUpgradeableProxy {
    /**
     * @notice Deploy the xBTC proxy contract
     * @dev Initializes the proxy with implementation, admin, and initialization data
     * @param logic Address of the xBTC implementation contract
     * @param admin Address that can upgrade the proxy (should be a multisig)
     * @param data Encoded initialization call to the implementation contract
     * 
     * Requirements:
     * - logic must be a valid contract address
     * - admin must not be the zero address
     * - data must be valid initialization call data
     */
    constructor(
        address logic,
        address admin,
        bytes memory data
    ) TransparentUpgradeableProxy(logic, admin, data) {
        // All proxy logic is handled by OpenZeppelin's TransparentUpgradeableProxy
        // This ensures maximum security and gas efficiency
        // No additional state variables or logic to minimize attack surface
    }

    /**
     * @notice This contract follows the transparent proxy pattern
     * @dev Admin functions are handled by the ProxyAdmin contract
     *      Regular users interact with the implementation through this proxy
     *      No additional functions needed - keeps the contract minimal and secure
     */
}

