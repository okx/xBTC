// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./DeployUtils.sol";
import {xToken} from "../contracts/xToken.sol";

/**
 * @title xSOL
 * @notice xSOL token with 9 decimals
 */
contract xSOL is xToken {
    function decimals() public pure override returns (uint8) {
        return 9;
    }
}

/**
 * @title DeployXSOL
 * @notice Foundry script to deploy xSOL token with proxy
 * @dev Uses EIP-2470 SingletonFactory for deterministic proxy deployment
 *
 * Environment variables required:
 * - ADMIN: Address that will receive DEFAULT_ADMIN_ROLE
 * - DENY_LISTER: Address that will receive DENY_LISTER_ROLE
 * - MINTER: Address that will receive MINTER_ROLE
 * - RECEIVER: Initial authorized receiver for minting operations
 * - PROXY_SALT: Salt for proxy deployment (optional)
 */
contract DeployXSOL is DeployUtils {
    // Token configuration (hardcoded)
    string public constant TOKEN_NAME = "OKX Wrapped SOL";
    string public constant TOKEN_SYMBOL = "xSOL";
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 9; // 1B with 9 decimals

    // Default salt (can be overridden via env)
    bytes32 public constant DEFAULT_PROXY_SALT = keccak256("okx-xSOL-proxy-v1");

    function run() external {
        // Read addresses from environment
        address admin = vm.envAddress("ADMIN");
        address denyLister = vm.envAddress("DENY_LISTER");
        address minter = vm.envAddress("MINTER");
        address receiver = vm.envAddress("RECEIVER");

        // Read optional salt from environment (with default)
        bytes32 proxySalt = _getEnvBytes32("PROXY_SALT", DEFAULT_PROXY_SALT);

        _logDeploymentInfo(TOKEN_NAME, TOKEN_SYMBOL, admin, denyLister, minter, receiver, MAX_SUPPLY, proxySalt);

        vm.startBroadcast();

        // Step 1: Deploy implementation (regular deployment)
        xSOL implementation = new xSOL();
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
        _verifyTokenDeployment(proxy, TOKEN_NAME, TOKEN_SYMBOL, 9, admin, denyLister, minter, receiver, MAX_SUPPLY);
        _logDeploymentComplete(TOKEN_NAME, proxy, address(implementation));
    }
}
