// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../contracts/Proxy.sol";
import "../contracts/Token.sol";
import "../contracts/StakedTokenV1.sol";
import "../contracts/ExchangeRateUpdater.sol";

/**
 * @title ISingletonFactory
 * @notice Interface for EIP-2470 Singleton Factory
 */
interface ISingletonFactory {
    function deploy(bytes memory _initCode, bytes32 _salt) external returns (address payable createdContract);
    function getAddress(bytes memory _initCode, bytes32 _salt) external view returns (address);
}

/**
 * @title DeployUtils
 * @notice Base contract with common deployment utilities for token deployments
 * @dev Uses EIP-2470 SingletonFactory for deterministic proxy deployment
 */
abstract contract DeployUtils is Script {
    // EIP-2470 SingletonFactory address (same on all chains)
    address public constant SINGLETON_FACTORY = 0xFaC897544659Fb136C064d5428947f5BC9cC1Fa2;

    /**
     * @notice Deploy proxy deterministically using EIP-2470 SingletonFactory
     * @param implementation Address of the implementation contract
     * @param admin Address that will receive DEFAULT_ADMIN_ROLE and proxy admin
     * @param initData Encoded initialization data for the proxy
     * @param salt Salt for deterministic deployment
     * @return proxy Address of the deployed proxy
     */
    function _deployProxyDeterministic(
        address implementation,
        address admin,
        bytes memory initData,
        bytes32 salt
    ) internal returns (address proxy) {
        // Create proxy init code with constructor args
        bytes memory proxyInitCode = abi.encodePacked(
            type(Proxy).creationCode,
            abi.encode(implementation, admin, initData)
        );

        ISingletonFactory factory = ISingletonFactory(SINGLETON_FACTORY);

        // Predict the deployment address before deploying
        address predictedAddress = factory.getAddress(proxyInitCode, salt);
        console.log("Predicted proxy address:", predictedAddress);

        // Check if already deployed
        if (predictedAddress.code.length > 0) {
            console.log("Proxy already deployed at predicted address");
            return predictedAddress;
        }

        // Deploy using EIP-2470 SingletonFactory
        address deployedAddress = factory.deploy(proxyInitCode, salt);

        require(deployedAddress == predictedAddress, "Proxy address mismatch");

        return deployedAddress;
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
        return abi.encodeWithSelector(
            Token.initialize.selector,
            name,
            symbol,
            admin,
            denyLister,
            minter,
            receiver,
            maxSupply
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
        uint256 maxSupply
    ) internal pure {
        console.log("=== Deployment Parameters ===");
        console.log("Name:", tokenName);
        console.log("Symbol:", tokenSymbol);
        console.log("Admin:", admin);
        console.log("Deny Lister:", denyLister);
        console.log("Minter:", minter);
        console.log("Receiver:", receiver);
        console.log("Max Supply:", maxSupply);
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
        Token token = Token(proxy);

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
