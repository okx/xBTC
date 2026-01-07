// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "scripts/DeployUtils.sol";
import {xETH} from "contracts/verify/xETH.sol";


/**
 * @title DeployXETH
 * @notice Foundry script to deploy xETH token with proxy
 * @dev Uses EIP-2470 SingletonFactory for deterministic proxy deployment
 *
 * Environment variables required:
 * - TIMELOCK_ADDRESS: Pre-deployed TimelockController address
 * - DENY_LISTER: Address that will receive DENY_LISTER_ROLE
 * - MINTER: Address that will receive MINTER_ROLE
 * - RECEIVER: Initial authorized receiver for minting operations
 */
contract DeployXETH is DeployUtils {
    // Token configuration (hardcoded)
    string public constant TOKEN_NAME = "OKX Wrapped ETH";
    string public constant TOKEN_SYMBOL = "xETH";
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 18; // 1B with 18 decimals

    function run() external {
        // Read addresses from environment
        address timelock = vm.envAddress("TIMELOCK_ADDRESS");
        address denyLister = vm.envAddress("DENY_LISTER");
        address minter = vm.envAddress("MINTER");
        address receiver = vm.envAddress("RECEIVER");

        // Single salt for implementation + proxy (global default in DeployUtils, override via env `SALT`)
        bytes32 salt = _salt();

        vm.startBroadcast();

        _logDeploymentInfo(TOKEN_NAME, TOKEN_SYMBOL, timelock, denyLister, minter, receiver, MAX_SUPPLY, salt);

        // Step 1: Deploy implementation deterministically via EIP-2470 (multi-chain consistent)
        address implementation = _deployDeterministic(type(xETH).creationCode, salt);
        console.log("Implementation deployed at:", implementation);

        // Step 2: Prepare initialization data (timelock as DEFAULT_ADMIN_ROLE)
        bytes memory initData = _encodeTokenInitData(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            timelock, // DEFAULT_ADMIN_ROLE
            denyLister,
            minter,
            receiver,
            MAX_SUPPLY
        );

        // Step 3: Deploy proxy with initialization (deterministic via EIP-2470, timelock as proxy admin)
        address proxy = _deployProxyDeterministic(
            implementation,
            timelock, // proxy admin
            initData,
            salt
        );
        console.log("Proxy deployed at:", proxy);

        vm.stopBroadcast();

        // Verify deployment
        _verifyEIP1967Proxy(proxy, implementation, timelock);
        _verifyTokenDeployment(proxy, TOKEN_NAME, TOKEN_SYMBOL, 18, timelock, denyLister, minter, receiver, MAX_SUPPLY);
        _logDeploymentComplete(TOKEN_NAME, proxy, implementation);
    }
}
