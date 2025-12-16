// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./DeployTimelock.s.sol";
import {xBETH} from "contracts/verify/xBETH.sol";
import {AtomicStakedTokenDeployer} from "scripts/AtomicStakedTokenDeployer.sol";


/**
 * @title DeployXBETH
 * @notice Foundry script to deploy xBETH staked token with proxy and oracle
 * @dev Uses EIP-2470 SingletonFactory for deterministic proxy deployment
 *      Deploys TimelockController first, sets it as proxy admin and DEFAULT_ADMIN_ROLE
 *      xBETH extends StakedTokenV1 which includes exchange rate oracle functionality
 *
 * Environment variables required:
 * - TIMELOCK_CALLER: Address that will be proposer and executor of timelock
 * - DENY_LISTER: Address that will receive DENY_LISTER_ROLE
 * - MINTER: Address that will receive MINTER_ROLE
 * - RECEIVER: Initial authorized receiver for minting operations
 * - ORACLE_OWNER: Address that owns the ExchangeRateUpdater
 * - ORACLE_CALLER: Address authorized to call updateExchangeRate
 */
contract DeployXBETH is TimelockDeployUtils {
    // Token configuration (hardcoded)
    string public constant TOKEN_NAME = "OKX Wrapped Staked ETH";
    string public constant TOKEN_SYMBOL = "xBETH";
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18; // 1B with 18 decimals

    // Oracle config (hardcoded)
    uint256 public constant INITIAL_EXCHANGE_RATE = 1e18; // 1:1 ratio
    uint256 public constant RATE_ALLOWANCE = 1e16; // 1% change allowed
    uint256 public constant RATE_INTERVAL = 1 days;

    function run() external {
        // Read addresses from environment
        address timelockCaller = vm.envAddress("TIMELOCK_CALLER");
        address denyLister = vm.envAddress("DENY_LISTER");
        address minter = vm.envAddress("MINTER");
        address receiver = vm.envAddress("RECEIVER");
        address oracleOwner = vm.envAddress("ORACLE_OWNER");
        address oracleCaller = vm.envAddress("ORACLE_CALLER");

        address singletonFactory = _singletonFactory();
        // Single salt for implementation + atomic deployer + proxy (global default in DeployUtils, override via env `SALT`)
        bytes32 salt = _salt();

        vm.startBroadcast();

        // Step 1: Deploy TimelockController deterministically (timelock as proxy admin and DEFAULT_ADMIN_ROLE)
        address timelock = _deployTimelockDeterministic(timelockCaller);
        console.log("TimelockController deployed at:", timelock);

        _logDeploymentInfo(TOKEN_NAME, TOKEN_SYMBOL, timelock, denyLister, minter, receiver, MAX_SUPPLY, salt);
        _logOracleInfo(oracleOwner, oracleCaller, INITIAL_EXCHANGE_RATE, RATE_ALLOWANCE, RATE_INTERVAL);

        // Step 2: Deploy implementation deterministically via EIP-2470 (multi-chain consistent)
        address implementation = _deployDeterministic(type(xBETH).creationCode, salt);
        console.log("Implementation deployed at:", implementation);

        // Step 3: Deterministically deploy AtomicStakedTokenDeployer (its address is baked into proxy initData via address(this))
        bytes memory atomicInitCode = abi.encodePacked(
            type(AtomicStakedTokenDeployer).creationCode,
            abi.encode(
                implementation,
                timelock, // proxyAdmin (timelock)
                TOKEN_NAME,
                TOKEN_SYMBOL,
                timelock, // tokenAdmin (timelock as DEFAULT_ADMIN_ROLE)
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

        vm.stopBroadcast();

        // Verify deployment
        _verifyTokenDeployment(proxy, TOKEN_NAME, TOKEN_SYMBOL, 18, timelock, denyLister, minter, receiver, MAX_SUPPLY);
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
