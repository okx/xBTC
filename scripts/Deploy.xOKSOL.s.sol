// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./DeployUtils.sol";
import {xOKSOL} from "contracts/verify/xOKSOL.sol";
import {AtomicStakedTokenDeployer} from "scripts/AtomicStakedTokenDeployer.sol";


/**
 * @title DeployXOKSOL
 * @notice Foundry script to deploy xOKSOL staked token with proxy and oracle
 * @dev Uses EIP-2470 SingletonFactory for deterministic proxy deployment
 *      xOKSOL extends StakedTokenV1 which includes exchange rate oracle functionality
 *
 * Environment variables required:
 * - ADMIN: Address that will receive DEFAULT_ADMIN_ROLE
 * - DENY_LISTER: Address that will receive DENY_LISTER_ROLE
 * - MINTER: Address that will receive MINTER_ROLE
 * - RECEIVER: Initial authorized receiver for minting operations
 * - ORACLE_OWNER: Address that owns the ExchangeRateUpdater
 * - ORACLE_CALLER: Address authorized to call updateExchangeRate
 */
contract DeployXOKSOL is DeployUtils {
    // Token configuration (hardcoded)
    string public constant TOKEN_NAME = "OKX Wrapped Staked SOL";
    string public constant TOKEN_SYMBOL = "xOKSOL";
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e9; // 1B with 9 decimals

    // Oracle config (hardcoded)
    uint256 public constant INITIAL_EXCHANGE_RATE = 1e18; // 1:1 ratio for 18 decimals
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
        address singletonFactory = _singletonFactory();

        // Single salt for implementation + atomic deployer + proxy (global default in DeployUtils, override via env `SALT`)
        bytes32 salt = _salt();

        _logDeploymentInfo(TOKEN_NAME, TOKEN_SYMBOL, admin, denyLister, minter, receiver, MAX_SUPPLY, salt);
        _logOracleInfo(oracleOwner, oracleCaller, INITIAL_EXCHANGE_RATE, RATE_ALLOWANCE, RATE_INTERVAL);

        vm.startBroadcast();

        // Step 1: Deploy implementation deterministically via EIP-2470 (multi-chain consistent)
        address implementation = _deployDeterministic(type(xOKSOL).creationCode, salt);
        console.log("Implementation deployed at:", implementation);

        // Step 2: Deterministically deploy AtomicStakedTokenDeployer (its address is baked into proxy initData via address(this))
        bytes memory atomicInitCode = abi.encodePacked(
            type(AtomicStakedTokenDeployer).creationCode,
            abi.encode(
                implementation,
                admin, // proxyAdmin
                TOKEN_NAME,
                TOKEN_SYMBOL,
                admin, // tokenAdmin
                denyLister,
                minter,
                receiver,
                MAX_SUPPLY,
                oracleOwner,
                oracleCaller,
                INITIAL_EXCHANGE_RATE,
                RATE_ALLOWANCE,
                RATE_INTERVAL,
                singletonFactory,
                salt
            )
        );
        address atomicAddr = _deployDeterministic(atomicInitCode, salt);
        AtomicStakedTokenDeployer atomic = AtomicStakedTokenDeployer(atomicAddr);
        address proxy = atomic.proxy();
        address exchangeRateUpdater = atomic.exchangeRateUpdater();
        console.log("Atomic deployer:", atomicAddr);
        console.log("Proxy deployed at:", proxy);
        console.log("ExchangeRateUpdater deployed at:", exchangeRateUpdater);

        // Verify deployment
        _verifyTokenDeployment(proxy, TOKEN_NAME, TOKEN_SYMBOL, 9, admin, denyLister, minter, receiver, MAX_SUPPLY);
        _verifyStakedTokenDeploymentComplete(
            proxy,
            exchangeRateUpdater,
            INITIAL_EXCHANGE_RATE,
            oracleOwner,
            oracleCaller,
            RATE_ALLOWANCE,
            RATE_INTERVAL
        );
        _logDeploymentComplete(TOKEN_NAME, proxy, implementation);
        _logOracleComplete(exchangeRateUpdater, oracleOwner, oracleCaller);
    }
}
