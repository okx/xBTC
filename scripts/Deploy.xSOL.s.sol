// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./DeployTimelock.s.sol";
import {xSOL} from "contracts/verify/xSOL.sol";


/**
 * @title DeployXSOL
 * @notice Foundry script to deploy xSOL token with proxy
 * @dev Uses EIP-2470 SingletonFactory for deterministic proxy deployment
 *      Deploys TimelockController first, sets it as proxy admin and DEFAULT_ADMIN_ROLE
 *
 * Environment variables required:
 * - TIMELOCK_CALLER: Address that will be proposer and executor of timelock
 * - DENY_LISTER: Address that will receive DENY_LISTER_ROLE
 * - MINTER: Address that will receive MINTER_ROLE
 * - RECEIVER: Initial authorized receiver for minting operations
 */
contract DeployXSOL is TimelockDeployUtils {
    // Token configuration (hardcoded)
    string public constant TOKEN_NAME = "OKX Wrapped SOL";
    string public constant TOKEN_SYMBOL = "xSOL";
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10 ** 9; // 1B with 9 decimals

    function run() external {
        // Read addresses from environment
        address timelockCaller = vm.envAddress("TIMELOCK_CALLER");
        address denyLister = vm.envAddress("DENY_LISTER");
        address minter = vm.envAddress("MINTER");
        address receiver = vm.envAddress("RECEIVER");

        // Single salt for implementation + proxy (global default in DeployUtils, override via env `SALT`)
        bytes32 salt = _salt();

        vm.startBroadcast();

        // Step 1: Deploy TimelockController deterministically (timelock as proxy admin and DEFAULT_ADMIN_ROLE)
        address timelock = _deployTimelockDeterministic(timelockCaller);
        console.log("TimelockController deployed at:", timelock);

        _logDeploymentInfo(TOKEN_NAME, TOKEN_SYMBOL, timelock, denyLister, minter, receiver, MAX_SUPPLY, salt);

        // Step 2: Deploy implementation deterministically via EIP-2470 (multi-chain consistent)
        address implementation = _deployDeterministic(type(xSOL).creationCode, salt);
        console.log("Implementation deployed at:", implementation);

        // Step 3: Prepare initialization data (timelock as DEFAULT_ADMIN_ROLE)
        bytes memory initData = _encodeTokenInitData(
            TOKEN_NAME,
            TOKEN_SYMBOL,
            timelock, // DEFAULT_ADMIN_ROLE
            denyLister,
            minter,
            receiver,
            MAX_SUPPLY
        );

        // Step 4: Deploy proxy with initialization (deterministic via EIP-2470, timelock as proxy admin)
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
        _verifyTokenDeployment(proxy, TOKEN_NAME, TOKEN_SYMBOL, 9, timelock, denyLister, minter, receiver, MAX_SUPPLY);
        _logDeploymentComplete(TOKEN_NAME, proxy, implementation);
    }
}
