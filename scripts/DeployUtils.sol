// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import {Proxy} from "contracts/Proxy.sol";
import {xToken} from "contracts/xToken.sol";
import {StakedTokenV1} from "contracts/StakedTokenV1.sol";
import {ExchangeRateUpdater} from "contracts/ExchangeRateUpdater.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ISingletonFactory
 * @notice Interface for EIP-2470 Singleton Factory
 */
interface ISingletonFactory {
    function deploy(bytes memory _initCode, bytes32 _salt) external returns (address payable createdContract);
}

/**
 * @title DeployUtils
 * @notice Base contract with common deployment utilities for token deployments
 * @dev Uses EIP-2470 SingletonFactory for deterministic proxy deployment
 */
abstract contract DeployUtils is Script {
    // EIP-2470 SingletonFactory default address
    address public constant DEFAULT_SINGLETON_FACTORY = 0xFaC897544659Fb136C064d5428947f5BC9cC1Fa2;
    // Global default salt for deterministic deployments
    bytes32 internal constant DEFAULT_SALT = keccak256("OKX-xAsset");

    // EIP-1967 slots
    bytes32 internal constant _EIP1967_IMPLEMENTATION_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    bytes32 internal constant _EIP1967_ADMIN_SLOT =
        bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);

    /**
     * @notice Get address from environment with fallback to default value
     */
    function _getEnvAddress(string memory key, address defaultValue) internal view returns (address) {
        try vm.envAddress(key) returns (address value) {
            return value;
        } catch {
            return defaultValue;
        }
    }

    /**
     * @notice EIP-2470 SingletonFactory address used for deterministic deployments
     * @dev Read from env `SINGLETON_FACTORY` with fallback to DEFAULT_SINGLETON_FACTORY.
     */
    function _singletonFactory() internal view returns (address) {
        return _getEnvAddress("SINGLETON_FACTORY", DEFAULT_SINGLETON_FACTORY);
    }

    function _salt() internal view returns (bytes32) {
        return _getEnvBytes32("SALT", DEFAULT_SALT);
    }

    /**
     * @notice Predict deterministic proxy address for EIP-2470 SingletonFactory CREATE2 deployment
     */
    function _predictDeterministicAddress(address singletonFactory, bytes memory initCode, bytes32 salt) internal pure returns (address) {
        bytes32 initCodeHash = keccak256(initCode);
        console.log("Singleton factory:");
        console.logAddress(singletonFactory);
        console.log("Init code hash:");
        console.logBytes32(initCodeHash);
        console.log("Salt:");
        console.logBytes32(salt);
        bytes32 raw = keccak256(abi.encodePacked(bytes1(0xff), singletonFactory, salt, initCodeHash));
        return address(uint160(uint256(raw)));
    }

    /**
     * @notice Deploy arbitrary init code deterministically using EIP-2470 SingletonFactory (CREATE2)
     * @dev Reverts if the predicted address is already occupied (fail-closed).
     */
    function _deployDeterministic(bytes memory initCode, bytes32 salt) internal returns (address deployed) {
        ISingletonFactory factory = ISingletonFactory(_singletonFactory());
        address predicted = _predictDeterministicAddress(address(factory), initCode, salt);
        console.log("Predicted address:", predicted);
        require(predicted.code.length == 0, "Already deployed at predicted address");
        address actual = factory.deploy(initCode, salt);
        require(actual == predicted, "Deterministic deploy address mismatch");
        return actual;
    }

    /**
     * @notice Deploy proxy deterministically using EIP-2470 SingletonFactory
     * @param implementation Address of the implementation contract
     * @param proxyAdmin Address that can upgrade the proxy (EIP-1967 admin slot)
     * @param initData Encoded initialization data for the proxy
     * @param salt Salt for deterministic deployment
     * @return proxy Address of the deployed proxy
     */
    function _deployProxyDeterministic(
        address implementation,
        address proxyAdmin,
        bytes memory initData,
        bytes32 salt
    ) internal returns (address proxy) {
        // Create proxy init code with constructor args
        bytes memory proxyInitCode = abi.encodePacked(
            type(Proxy).creationCode,
            abi.encode(implementation, proxyAdmin, initData)
        );
        return _deployDeterministic(proxyInitCode, salt);
    }

    /**
     * @notice Verify EIP-1967 proxy slots (implementation/admin) match expectations
     * @dev Uses Foundry cheatcode `vm.load` so it works even though proxies don't expose admin().
     */
    function _verifyEIP1967Proxy(
        address proxy,
        address expectedImplementation,
        address expectedProxyAdmin
    ) internal view {
        bytes32 implSlot = vm.load(proxy, _EIP1967_IMPLEMENTATION_SLOT);
        bytes32 adminSlot = vm.load(proxy, _EIP1967_ADMIN_SLOT);
        address proxyAdmin = Ownable(address(uint160(uint256(adminSlot)))).owner();
        require(address(uint160(uint256(implSlot))) == expectedImplementation, "EIP1967: implementation mismatch");
        require(proxyAdmin == expectedProxyAdmin, "EIP1967: admin mismatch");
    }

    /**
     * @notice Encode initialization data for Token contract
     * @param name Token name
     * @param symbol Token symbol
     * @param admin Address that will receive DEFAULT_ADMIN_ROLE
     * @param denyLister Address that will receive DENY_LISTER_ROLE
     * @param minter Address that will receive MINTER_ROLE
     * @param receiver Initial authorized receiver for minting
     * @param maxSupply Maximum token supply
     * @return Encoded initialization data
     */
    function _encodeTokenInitData(
        string memory name,
        string memory symbol,
        address admin,
        address denyLister,
        address minter,
        address receiver,
        uint256 maxSupply
    ) internal pure returns (bytes memory) {
        // Use abi.encodeCall for compile-time type checking
        return abi.encodeCall(
            xToken.initialize,
            (name, symbol, admin, denyLister, minter, receiver, maxSupply)
        );
    }

    /**
     * @notice Get bytes32 from environment with fallback to default value
     * @param key Environment variable key
     * @param defaultValue Default value if env var not set
     * @return value The environment value or default
     */
    function _getEnvBytes32(string memory key, bytes32 defaultValue) internal view returns (bytes32) {
        try vm.envBytes32(key) returns (bytes32 value) {
            return value;
        } catch {
            return defaultValue;
        }
    }

    /**
     * @notice Log all initialization parameters
     * @param tokenName Name of the token
     * @param tokenSymbol Symbol of the token
     * @param admin Admin address (DEFAULT_ADMIN_ROLE)
     * @param denyLister Deny lister address (DENY_LISTER_ROLE)
     * @param minter Minter address (MINTER_ROLE)
     * @param receiver Authorized receiver address
     * @param maxSupply Maximum supply
     */
    function _logDeploymentInfo(
        string memory tokenName,
        string memory tokenSymbol,
        address admin,
        address denyLister,
        address minter,
        address receiver,
        uint256 maxSupply,
        bytes32 salt
    ) internal view {
        console.log("=== Deployment Parameters ===");
        console.log("Name:", tokenName);
        console.log("Symbol:", tokenSymbol);
        console.log("Admin:", admin);
        console.log("Deny Lister:", denyLister);
        console.log("Minter:", minter);
        console.log("Receiver:", receiver);
        console.log("Max Supply:", maxSupply);
        console.log("Factory:", _singletonFactory());
        console.log("Salt:");
        console.logBytes32(salt);
        console.log("");
    }

    /**
     * @notice Log deployment completion
     * @param tokenName Name of the token
     * @param proxy Proxy address
     * @param implementation Implementation address
     */
    function _logDeploymentComplete(
        string memory tokenName,
        address proxy,
        address implementation
    ) internal pure {
        console.log("");
        console.log("=== Deployment Complete ===");
        console.log(string.concat(tokenName, " Proxy Address:"), proxy);
        console.log(string.concat(tokenName, " Implementation:"), implementation);
    }

    /**
     * @notice Verify token deployment against expected values
     * @param proxy Address of the deployed proxy
     * @param expectedName Expected token name
     * @param expectedSymbol Expected token symbol
     * @param expectedDecimals Expected token decimals
     * @param expectedAdmin Expected admin address (DEFAULT_ADMIN_ROLE)
     * @param expectedDenyLister Expected deny lister address (DENY_LISTER_ROLE)
     * @param expectedMinter Expected minter address (MINTER_ROLE)
     * @param expectedReceiver Expected authorized receiver
     * @param expectedMaxSupply Expected max supply
     */
    function _verifyTokenDeployment(
        address proxy,
        string memory expectedName,
        string memory expectedSymbol,
        uint8 expectedDecimals,
        address expectedAdmin,
        address expectedDenyLister,
        address expectedMinter,
        address expectedReceiver,
        uint256 expectedMaxSupply
    ) internal view {
        xToken token = xToken(proxy);

        console.log("");
        console.log("=== Verification ===");

        // Verify name
        string memory actualName = token.name();
        require(
            keccak256(bytes(actualName)) == keccak256(bytes(expectedName)),
            string.concat("Name mismatch: expected ", expectedName, ", got ", actualName)
        );

        // Verify symbol
        string memory actualSymbol = token.symbol();
        require(
            keccak256(bytes(actualSymbol)) == keccak256(bytes(expectedSymbol)),
            string.concat("Symbol mismatch: expected ", expectedSymbol, ", got ", actualSymbol)
        );

        // Verify decimals
        uint8 actualDecimals = token.decimals();
        require(actualDecimals == expectedDecimals, "Decimals mismatch");

        // Verify admin has DEFAULT_ADMIN_ROLE
        require(
            token.hasRole(token.DEFAULT_ADMIN_ROLE(), expectedAdmin),
            "Admin does not have DEFAULT_ADMIN_ROLE"
        );

        // Verify denyLister has DENY_LISTER_ROLE
        require(
            token.hasRole(token.DENY_LISTER_ROLE(), expectedDenyLister),
            "DenyLister does not have DENY_LISTER_ROLE"
        );

        // Verify minter has MINTER_ROLE
        require(
            token.hasRole(token.MINTER_ROLE(), expectedMinter),
            "Minter does not have MINTER_ROLE"
        );

        // Verify authorized receiver
        address actualReceiver = token.authorizedReceiver();
        require(actualReceiver == expectedReceiver, "Authorized receiver mismatch");

        // Verify max supply
        uint256 actualMaxSupply = token.MAX_SUPPLY();
        require(actualMaxSupply == expectedMaxSupply, "Max supply mismatch");

        console.log("Verification passed!");
    }

    /**
     * @notice Log oracle configuration parameters
     * @param oracleOwner Owner of ExchangeRateUpdater
     * @param oracleCaller Authorized caller for rate updates
     * @param initialExchangeRate Initial exchange rate
     * @param rateAllowance Rate limit allowance
     * @param rateInterval Rate limit interval in seconds
     */
    function _logOracleInfo(
        address oracleOwner,
        address oracleCaller,
        uint256 initialExchangeRate,
        uint256 rateAllowance,
        uint256 rateInterval
    ) internal pure {
        console.log("=== Oracle Parameters ===");
        console.log("Oracle Owner:", oracleOwner);
        console.log("Oracle Caller:", oracleCaller);
        console.log("Initial Exchange Rate:", initialExchangeRate);
        console.log("Rate Allowance:", rateAllowance);
        console.log("Rate Interval:", rateInterval);
        console.log("");
    }

    /**
     * @notice Initialize oracle for staked token (steps 4-9)
     * @param stakedToken Address of the staked token proxy
     * @param admin Admin address with DEFAULT_ADMIN_ROLE
     * @param oracleOwner Owner of ExchangeRateUpdater
     * @param oracleCaller Authorized caller for rate updates
     * @param initialExchangeRate Initial exchange rate
     * @param rateAllowance Rate limit allowance
     * @param rateInterval Rate limit interval in seconds
     * @return exchangeRateUpdater Address of deployed ExchangeRateUpdater
     */
    function _initializeStakedTokenOracle(
        address stakedToken,
        address admin,
        address oracleOwner,
        address oracleCaller,
        uint256 initialExchangeRate,
        uint256 rateAllowance,
        uint256 rateInterval
    ) internal returns (address exchangeRateUpdater) {
        StakedTokenV1 token = StakedTokenV1(stakedToken);

        // Step 4: Set oracle_owner as oracle first to set initial exchange rate
        vm.stopBroadcast();
        vm.startBroadcast(admin);
        token.updateOracle(oracleOwner);
        console.log("Oracle set to oracle owner:", oracleOwner);
        vm.stopBroadcast();

        // Step 5: Set initial exchange rate
        vm.startBroadcast(oracleOwner);
        token.updateExchangeRate(initialExchangeRate);
        console.log("Initial exchange rate set:", initialExchangeRate);

        // Step 6: Deploy ExchangeRateUpdater
        ExchangeRateUpdater updater = new ExchangeRateUpdater(oracleOwner);
        console.log("ExchangeRateUpdater deployed at:", address(updater));

        // Step 7: Initialize ExchangeRateUpdater
        updater.initialize(oracleOwner, stakedToken);
        console.log("ExchangeRateUpdater initialized");
        vm.stopBroadcast();

        // Step 8: Set ExchangeRateUpdater as oracle
        vm.startBroadcast(admin);
        token.updateOracle(address(updater));
        console.log("Oracle updated to ExchangeRateUpdater:", address(updater));
        vm.stopBroadcast();

        // Step 9: Configure caller with rate limit
        vm.startBroadcast(oracleOwner);
        updater.configureCaller(oracleCaller, rateAllowance, rateInterval);
        console.log("Caller configured:", oracleCaller);
        vm.stopBroadcast();

        return address(updater);
    }

    /**
     * @notice Verify staked token oracle deployment
     * @param proxy Address of the staked token proxy
     * @param expectedOracle Expected oracle address (ExchangeRateUpdater)
     * @param expectedExchangeRate Expected exchange rate
     */
    function _verifyStakedTokenDeployment(
        address proxy,
        address expectedOracle,
        uint256 expectedExchangeRate
    ) internal view {
        StakedTokenV1 token = StakedTokenV1(proxy);

        // Verify oracle is set to ExchangeRateUpdater
        address actualOracle = token.oracle();
        require(actualOracle == expectedOracle, "Oracle mismatch");
        console.log("Oracle:", actualOracle);

        // Verify exchange rate
        uint256 actualExchangeRate = token.exchangeRate();
        require(actualExchangeRate == expectedExchangeRate, "Exchange rate mismatch");
        console.log("Exchange Rate:", actualExchangeRate);
    }

    /**
     * @notice Verify staked token + ExchangeRateUpdater configuration (oracle, rate, ownership, caller limits)
     * @dev This is meant to be a "fail-closed" guard against CPIMP/front-run style partial-config deployments.
     */
    function _verifyStakedTokenDeploymentComplete(
        address proxy,
        address expectedUpdaterOracle,
        uint256 expectedExchangeRate,
        address expectedOracleOwner,
        address expectedOracleCaller,
        uint256 expectedRateAllowance,
        uint256 expectedRateInterval
    ) internal view {
        StakedTokenV1 token = StakedTokenV1(proxy);
        ExchangeRateUpdater updater = ExchangeRateUpdater(expectedUpdaterOracle);

        // Token-side checks
        address actualOracle = token.oracle();
        require(actualOracle == expectedUpdaterOracle, "Oracle mismatch");

        uint256 actualExchangeRate = token.exchangeRate();
        require(actualExchangeRate == expectedExchangeRate, "Exchange rate mismatch");

        // Updater-side checks
        require(updater.owner() == expectedOracleOwner, "Updater owner mismatch");
        require(updater.tokenContract() == proxy, "Updater tokenContract mismatch");
        require(updater.callers(expectedOracleCaller), "Updater caller not enabled");
        require(updater.maxAllowances(expectedOracleCaller) == expectedRateAllowance, "Caller allowance mismatch");
        require(updater.allowances(expectedOracleCaller) == expectedRateAllowance, "Caller stored allowance mismatch");
        require(updater.intervals(expectedOracleCaller) == expectedRateInterval, "Caller interval mismatch");

        console.log("Oracle:", actualOracle);
        console.log("Exchange Rate:", actualExchangeRate);
        console.log("Updater Owner:", updater.owner());
        console.log("Updater TokenContract:", updater.tokenContract());
        console.log("Caller Enabled:", updater.callers(expectedOracleCaller));
        console.log("Caller Allowance:", updater.maxAllowances(expectedOracleCaller));
        console.log("Caller Interval:", updater.intervals(expectedOracleCaller));
    }

    /**
     * @notice Log oracle configuration summary
     * @param exchangeRateUpdater Address of ExchangeRateUpdater
     * @param oracleOwner Owner address
     * @param oracleCaller Caller address
     */
    function _logOracleComplete(
        address exchangeRateUpdater,
        address oracleOwner,
        address oracleCaller
    ) internal pure {
        console.log("");
        console.log("=== Oracle Configuration ===");
        console.log("ExchangeRateUpdater:", exchangeRateUpdater);
        console.log("Oracle Owner:", oracleOwner);
        console.log("Oracle Caller:", oracleCaller);
    }
}
