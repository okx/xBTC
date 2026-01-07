// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./xTokenTestUtils.sol";
import {StakedTokenV1} from "../contracts/StakedTokenV1.sol";
import {ExchangeRateUpdater} from "../contracts/ExchangeRateUpdater.sol";

/**
 * @title StakedTokenTestUtils
 * @notice Extended test utilities for StakedToken testing
 * @dev Extends TestUtils with oracle and exchange rate testing
 */
abstract contract StakedTokenTestUtils is TestUtils {
    StakedTokenV1 public stakedToken;
    ExchangeRateUpdater public exchangeRateUpdater;
    
    // Oracle configuration (to be provided by subclasses)
    function getInitialExchangeRate() internal pure virtual returns (uint256);
    function getRateAllowance() internal pure virtual returns (uint256);
    function getRateInterval() internal pure virtual returns (uint256);
    
    function runStakedTokenTests() internal {
        // Read private keys from environment
        adminPK = vm.envUint("ADMIN_PK");
        testAccountPK = vm.envUint("TEST_ACCOUNT_PK");
        
        // Derive addresses from private keys
        admin = vm.addr(adminPK);
        testAccount = vm.addr(testAccountPK);
        
        console.log("\n=== Starting", getTokenName(), "Comprehensive Test ===\n");
        console.log("Admin (Deployer):", admin);
        console.log("Test Account:", testAccount);
        console.log("");
        
        // Special Step 1: Deploy contracts including oracle
        deployStakedTokenContracts();
        
        // Step 2: Test all read functions
        testReadFunctions();
        
        // Special Step 3: Test oracle functions
        testOracleFunctions();
        
        // Special Step 4: Test exchange rate update
        testExchangeRateUpdate();
        
        // Special Step 5: Test caller management
        testCallerManagement();
        
        // Step 6: Test minting
        testMinting();
        
        // Step 7: Test ERC20 transfers
        testTransfers();
        
        // Step 8: Test ERC20 approvals
        testApprovals();
        
        // Step 9: Test pause/unpause
        testPauseUnpause();
        
        // Step 10: Test deny list functions
        testDenyList();
        
        // Step 11: Test batch deny list operations
        testBatchDenyList();
        
        // Step 12: Test receiver management
        testReceiverManagement();
        
        // Step 13: Test role transfers
        testRoleTransfers();
        
        // Step 14: Test burning
        testBurning();
        
        console.log("\n=== All Tests Completed Successfully! ===\n");
    }
    
    function deployStakedTokenContracts() internal {
        console.log(">>> Test 1: Deploying Contracts (StakedToken + Oracle)");
        
        vm.startBroadcast(adminPK);
        
        // Deploy implementation (subclass-specific)
        address implementation = deployImplementation();
        console.log("Implementation deployed at:", implementation);
        
        // Prepare initialization data
        bytes memory initData = abi.encodeCall(
            xToken.initialize,
            (
                getTokenName(),
                getTokenSymbol(),
                admin,          // DEFAULT_ADMIN_ROLE
                admin,          // DENY_LISTER_ROLE
                admin,          // MINTER_ROLE
                admin,          // authorized receiver
                getMaxSupply()
            )
        );
        
        // Deploy proxy
        proxy = new Proxy(implementation, admin, initData);
        console.log("Proxy deployed at:", address(proxy));
        
        token = xToken(address(proxy));
        stakedToken = StakedTokenV1(address(proxy));
        
        // Set oracle_owner as oracle first to set initial exchange rate
        stakedToken.updateOracle(admin);
        stakedToken.updateExchangeRate(getInitialExchangeRate());

        // Deploy ExchangeRateUpdater with admin as initial owner
        exchangeRateUpdater = new ExchangeRateUpdater(admin);
        console.log("ExchangeRateUpdater deployed at:", address(exchangeRateUpdater));
        
        // Initialize ExchangeRateUpdater (admin as owner, testAccount as first caller)
        exchangeRateUpdater.initialize(admin, address(proxy));
        console.log("ExchangeRateUpdater initialized");
        
        // Configure rate limit
        exchangeRateUpdater.configureCaller(testAccount, getRateAllowance(), getRateInterval());
        console.log("Rate limit configured for testAccount");
        
        // Set ExchangeRateUpdater as oracle
        stakedToken.updateOracle(address(exchangeRateUpdater));
        console.log("Oracle set to ExchangeRateUpdater");
        vm.stopBroadcast();
        
        console.log("[PASS] Deployment successful\n");
    }
    
    function testOracleFunctions() internal view {
        console.log(">>> Test 3: Testing Oracle Functions");
        
        // Test oracle()
        address currentOracle = stakedToken.oracle();
        console.log("oracle():", currentOracle);
        require(currentOracle == address(exchangeRateUpdater), "Oracle mismatch");
        
        // Test exchangeRate()
        uint256 rate = stakedToken.exchangeRate();
        console.log("exchangeRate():", rate);
        require(rate == getInitialExchangeRate(), "Exchange rate mismatch");
        
        console.log("[PASS] Oracle functions tested\n");
    }
    
    function testExchangeRateUpdate() internal {
        console.log(">>> Test 4: Testing Exchange Rate Update");
        
        uint256 oldRate = stakedToken.exchangeRate();
        uint256 newRate = oldRate + (getRateAllowance() / 2); // Increase by 0.5%
        
        console.log("Current exchange rate:", oldRate);
        console.log("New exchange rate:", newRate);
        
        // TestAccount updates exchange rate (has caller permission)
        vm.startBroadcast(testAccountPK);
        exchangeRateUpdater.updateExchangeRate(newRate);
        vm.stopBroadcast();
        
        uint256 updatedRate = stakedToken.exchangeRate();
        console.log("Updated exchange rate:", updatedRate);
        require(updatedRate == newRate, "Exchange rate update failed");
        
        console.log("[PASS] Exchange rate update successful\n");
    }
    
    
    function testCallerManagement() internal {
        console.log(">>> Test 6: Testing Caller Management");
        
        // Create a new test address
        address newCaller = address(0x9999);
        
        // Admin adds new caller
        vm.startBroadcast(adminPK);
        exchangeRateUpdater.configureCaller(newCaller, getRateAllowance(), getRateInterval());
        vm.stopBroadcast();
        
        // Check if caller is configured
        bool isWhitelisted = exchangeRateUpdater.callers(newCaller);
        console.log("New caller whitelisted:", isWhitelisted);
        require(isWhitelisted, "Caller not whitelisted");
        
        // Admin removes caller
        vm.startBroadcast(adminPK);
        exchangeRateUpdater.removeCaller(newCaller);
        vm.stopBroadcast();
        
        // Check if caller is removed
        isWhitelisted = exchangeRateUpdater.callers(newCaller);
        console.log("Caller removed:", !isWhitelisted);
        require(!isWhitelisted, "Caller not removed");
        
        console.log("[PASS] Caller management successful\n");
    }
    
    function testOracleUpdate() internal {
        console.log(">>> Test (Extra): Testing Oracle Update");
        
        // Create a new oracle address (dummy)
        address newOracle = address(0x8888);
        
        // Admin updates oracle
        vm.startBroadcast(adminPK);
        stakedToken.updateOracle(newOracle);
        vm.stopBroadcast();
        
        address updatedOracle = stakedToken.oracle();
        console.log("Updated oracle:", updatedOracle);
        require(updatedOracle == newOracle, "Oracle update failed");
        
        // Set back to exchangeRateUpdater
        vm.startBroadcast(adminPK);
        stakedToken.updateOracle(address(exchangeRateUpdater));
        vm.stopBroadcast();
        
        console.log("[PASS] Oracle update successful\n");
    }
}

