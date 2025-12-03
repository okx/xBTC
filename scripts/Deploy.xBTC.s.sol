// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./DeployUtils.sol";
import "../contracts/Token.sol";

/**
 * @title xBTC
 * @notice xBTC token with 8 decimals
 */
contract xBTC is Token {
    function decimals() public pure override returns (uint8) {
        return 8;
    }
}

/**
 * @title DeployXBTC
 * @notice Foundry script to deploy xBTC token with proxy
 * @dev Uses EIP-2470 SingletonFactory for deterministic proxy deployment
 *
 * Environment variables required:
 * - ADMIN: Address that will receive DEFAULT_ADMIN_ROLE
 * - DENY_LISTER: Address that will receive DENY_LISTER_ROLE
 * - MINTER: Address that will receive MINTER_ROLE
 * - RECEIVER: Initial authorized receiver for minting operations
 * - PROXY_SALT: Salt for proxy deployment (optional)
 */
contract DeployXBTC is DeployUtils {
    // Token configuration (hardcoded)
    string public constant TOKEN_NAME = "xBTC";
    string public constant TOKEN_SYMBOL = "xBTC";
    uint256 public constant MAX_SUPPLY = 21_000_000 * 10 ** 8; // 21M with 8 decimals

    // Default salt (can be overridden via env)
    bytes32 public constant DEFAULT_PROXY_SALT = keccak256("okx-xBTC-proxy-v1");

    function run() external {
        // Read addresses from environment
        address admin = vm.envAddress("ADMIN");
        address denyLister = vm.envAddress("DENY_LISTER");
        address minter = vm.envAddress("MINTER");
        address receiver = vm.envAddress("RECEIVER");

        // Read optional salt from environment (with default)
        bytes32 proxySalt = _getEnvBytes32("PROXY_SALT", DEFAULT_PROXY_SALT);

        _logDeploymentInfo(TOKEN_NAME, TOKEN_SYMBOL, admin, denyLister, minter, receiver, MAX_SUPPLY);

        vm.startBroadcast();

        // Step 1: Deploy implementation (regular deployment)
        xBTC implementation = new xBTC();
        console.log("Implementation deployed at:", address(implementation));

        // Step 2: Prepare initialization data
        bytes memory initData = _encodeTokenInitData(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            admin,
            denyLister,
            minter,
            receiver,
            MAX_SUPPLY
        );

        // Step 3: Deploy proxy with initialization (deterministic via EIP-2470)
        address proxy = _deployProxyDeterministic(
            address(implementation),
            admin,
            initData,
            proxySalt
        );
        console.log("Proxy deployed at:", proxy);

        vm.stopBroadcast();

        // Verify deployment
        _verifyTokenDeployment(proxy, TOKEN_NAME, TOKEN_SYMBOL, 8, admin, denyLister, minter, receiver, MAX_SUPPLY);
        _logDeploymentComplete(TOKEN_NAME, proxy, address(implementation));
    }
}
