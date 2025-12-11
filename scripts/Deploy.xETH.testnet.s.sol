// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./DeployUtils.sol";
import {xToken} from "../contracts/xToken.sol";
import {Proxy} from "../contracts/Proxy.sol";

/**
 * @title xETH
 * @notice xETH token with 18 decimals
 */
contract xETH is xToken {
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}

/**
 * @title DeployXETH
 * @notice Foundry script to deploy xETH token with proxy
 *
 * Environment variables required:
 * - ADMIN: Address that will receive DEFAULT_ADMIN_ROLE
 * - DENY_LISTER: Address that will receive DENY_LISTER_ROLE
 * - MINTER: Address that will receive MINTER_ROLE
 * - RECEIVER: Initial authorized receiver for minting operations
 */
contract DeployXETH is DeployUtils {
    // Token configuration (hardcoded)
    string public constant TOKEN_NAME = "OKX Wrapped ETH";
    string public constant TOKEN_SYMBOL = "xETH";
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10 ** 18; // 100M with 18 decimals

    function run() external {
        // Read addresses from environment
        address admin = vm.envAddress("ADMIN");
        address denyLister = vm.envAddress("DENY_LISTER");
        address minter = vm.envAddress("MINTER");
        address receiver = vm.envAddress("RECEIVER");

        _logDeploymentInfo(TOKEN_NAME, TOKEN_SYMBOL, admin, denyLister, minter, receiver, MAX_SUPPLY, bytes32(0));

        vm.startBroadcast();

        // Step 1: Deploy implementation (regular deployment)
        xETH implementation = new xETH();
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

        // Step 3: Deploy proxy with initialization (direct deployment)
        Proxy proxy = new Proxy(
            address(implementation),
            admin,
            initData
        );
        console.log("Proxy deployed at:", address(proxy));

        vm.stopBroadcast();

        // Verify deployment
        _verifyTokenDeployment(address(proxy), TOKEN_NAME, TOKEN_SYMBOL, 18, admin, denyLister, minter, receiver, MAX_SUPPLY);
        _logDeploymentComplete(TOKEN_NAME, address(proxy), address(implementation));
    }
}
