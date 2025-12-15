// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./DeployUtils.sol";

/**
 * @title xBETH
 * @notice xBETH staked token with 18 decimals
 * @dev Extends StakedTokenV1 which includes exchange rate oracle functionality
 */
contract xBETH is StakedTokenV1 {
    function decimals() public pure override returns (uint8) {
        return 18;
    }
}

/**
 * @title DeployXBETH
 * @notice Foundry script to deploy xBETH staked token with proxy and oracle
 * @dev Uses EIP-2470 SingletonFactory for deterministic proxy deployment
 *      xBETH extends StakedTokenV1 which includes exchange rate oracle functionality
 *
 * Environment variables required:
 * - ADMIN: Address that will receive DEFAULT_ADMIN_ROLE
 * - DENY_LISTER: Address that will receive DENY_LISTER_ROLE
 * - MINTER: Address that will receive MINTER_ROLE
 * - RECEIVER: Initial authorized receiver for minting operations
 * - ORACLE_OWNER: Address that owns the ExchangeRateUpdater
 * - ORACLE_CALLER: Address authorized to call updateExchangeRate
 * - PROXY_SALT: Salt for proxy deployment (optional)
 */
contract DeployXBETH is DeployUtils {
    // Token configuration (hardcoded)
    string public constant TOKEN_NAME = "OKX Wrapped Staked ETH";
    string public constant TOKEN_SYMBOL = "xBETH";
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18; // 1B with 18 decimals

    // Default salt (can be overridden via env)
    bytes32 public constant DEFAULT_PROXY_SALT = keccak256("okx-xBETH-proxy-v1");

    // Oracle config (hardcoded)
    uint256 public constant INITIAL_EXCHANGE_RATE = 1e18; // 1:1 ratio
    uint256 public constant RATE_ALLOWANCE = 1e16; // 1% change allowed
    uint256 public constant RATE_INTERVAL = 1 days;

    function run() external {
        // Read addresses from environment
        address admin = vm.envAddress("ADMIN");
        address denyLister = vm.envAddress("DENY_LISTER");
        address minter = vm.envAddress("MINTER");
        address receiver = vm.envAddress("RECEIVER");
        address oracleOwner = vm.envAddress("ORACLE_OWNER");
        address oracleCaller = vm.envAddress("ORACLE_CALLER");

        // Read optional salt from environment (with default)
        bytes32 proxySalt = _getEnvBytes32("PROXY_SALT", DEFAULT_PROXY_SALT);

        _logDeploymentInfo(TOKEN_NAME, TOKEN_SYMBOL, admin, denyLister, minter, receiver, MAX_SUPPLY, proxySalt);
        _logOracleInfo(oracleOwner, oracleCaller, INITIAL_EXCHANGE_RATE, RATE_ALLOWANCE, RATE_INTERVAL);

        vm.startBroadcast();

        // Step 1: Deploy implementation (regular deployment)
        xBETH implementation = new xBETH();
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

        // Steps 4-9: Initialize oracle
        address exchangeRateUpdater = _initializeStakedTokenOracle(
            proxy,
            admin,
            oracleOwner,
            oracleCaller,
            INITIAL_EXCHANGE_RATE,
            RATE_ALLOWANCE,
            RATE_INTERVAL
        );

        // Verify deployment
        _verifyTokenDeployment(proxy, TOKEN_NAME, TOKEN_SYMBOL, 18, admin, denyLister, minter, receiver, MAX_SUPPLY);
        _verifyStakedTokenDeployment(proxy, exchangeRateUpdater, INITIAL_EXCHANGE_RATE);
        _logDeploymentComplete(TOKEN_NAME, proxy, address(implementation));
        _logOracleComplete(exchangeRateUpdater, oracleOwner, oracleCaller);
    }
}
