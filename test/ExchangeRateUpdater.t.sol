// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ExchangeRateUpdater} from "../contracts/ExchangeRateUpdater.sol";
import {StakedTokenV1} from "../contracts/StakedTokenV1.sol";
import {Token} from "../contracts/Token.sol";
import {Proxy} from "../contracts/Proxy.sol";

/**
 * @title ExchangeRateUpdaterTest
 * @notice Comprehensive unit tests for ExchangeRateUpdater contract
 * @dev Tests exchange rate updates with StakedTokenV1 as the oracle target
 */
contract ExchangeRateUpdaterTest is Test {
    ExchangeRateUpdater public exchangeRateUpdater;
    StakedTokenV1 public stakedToken;
    Proxy public proxy;

    // Test accounts
    address public deployer;
    address public owner;
    address public caller1;
    address public caller2;
    address public nonCaller;
    address public admin;
    address public minter;
    address public receiver;

    // Constants
    uint256 public constant ALLOWANCE = 1e16; // ~1% rate change per day
    uint256 public constant INTERVAL = 1 days;
    uint256 public constant INITIAL_EXCHANGE_RATE = 1e18; // 1:1 initial rate
    uint256 public constant DECIMALS = 18;
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10 ** DECIMALS;

    // Events (must match contract)
    event ExchangeRateUpdated(address indexed caller, uint256 amount);
    event CallerConfigured(address indexed caller, uint256 amount, uint256 interval);
    event CallerRemoved(address indexed caller);

    function setUp() public {
        deployer = address(this);
        owner = makeAddr("owner");
        caller1 = makeAddr("caller1");
        caller2 = makeAddr("caller2");
        nonCaller = makeAddr("nonCaller");
        admin = makeAddr("admin");
        minter = makeAddr("minter");
        receiver = makeAddr("receiver");

        // Deploy StakedTokenV1 implementation
        StakedTokenV1 implementation = new StakedTokenV1();

        // Prepare initialization data (initialize is inherited from Token)
        bytes memory initData = abi.encodeWithSelector(
            Token.initialize.selector,
            "OKX Staked ETH",
            "xBETH",
            admin,     // denyLister / DEFAULT_ADMIN_ROLE
            minter,    // MINTER_ROLE
            receiver,  // authorized receiver
            MAX_SUPPLY
        );

        // Deploy proxy
        proxy = new Proxy(
            address(implementation),
            admin,
            initData
        );

        // Get the token through the proxy
        stakedToken = StakedTokenV1(address(proxy));

        // Deploy ExchangeRateUpdater with deployer as initial owner
        exchangeRateUpdater = new ExchangeRateUpdater(deployer);

        // Initialize the ExchangeRateUpdater
        exchangeRateUpdater.initialize(owner, address(stakedToken));

        // Set ExchangeRateUpdater as the oracle on StakedTokenV1
        vm.prank(admin);
        stakedToken.updateOracle(address(exchangeRateUpdater));

        // Set initial exchange rate on StakedTokenV1
        vm.prank(address(exchangeRateUpdater));
        stakedToken.updateExchangeRate(INITIAL_EXCHANGE_RATE);

        // Configure caller1 as a whitelisted caller
        vm.prank(owner);
        exchangeRateUpdater.configureCaller(caller1, ALLOWANCE, INTERVAL);
    }

    // ============ Constructor Tests ============

    function test_Constructor_SetsInitialOwner() public {
        ExchangeRateUpdater newUpdater = new ExchangeRateUpdater(owner);
        assertEq(newUpdater.owner(), owner);
    }

    function test_Constructor_RevertWhen_ZeroAddressOwner() public {
        vm.expectRevert(abi.encodeWithSignature("OwnableInvalidOwner(address)", address(0)));
        new ExchangeRateUpdater(address(0));
    }

    // ============ Initialize Tests ============

    function test_Initialize_SetsOwnerAndTokenContract() public view {
        assertEq(exchangeRateUpdater.owner(), owner);
        assertEq(exchangeRateUpdater.tokenContract(), address(stakedToken));
    }

    function test_Initialize_RevertWhen_CalledTwice() public {
        vm.prank(owner);
        vm.expectRevert("ExchangeRateUpdater: contract is already initialized");
        exchangeRateUpdater.initialize(owner, address(stakedToken));
    }

    function test_Initialize_RevertWhen_ZeroAddressOwner() public {
        ExchangeRateUpdater newUpdater = new ExchangeRateUpdater(deployer);
        
        vm.expectRevert("ExchangeRateUpdater: owner is the zero address");
        newUpdater.initialize(address(0), address(stakedToken));
    }

    function test_Initialize_RevertWhen_ZeroAddressTokenContract() public {
        ExchangeRateUpdater newUpdater = new ExchangeRateUpdater(deployer);
        
        vm.expectRevert("ExchangeRateUpdater: tokenContract is the zero address");
        newUpdater.initialize(owner, address(0));
    }

    function test_Initialize_RevertWhen_NotOwner() public {
        ExchangeRateUpdater newUpdater = new ExchangeRateUpdater(deployer);
        
        vm.prank(nonCaller);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", nonCaller));
        newUpdater.initialize(owner, address(stakedToken));
    }

    // ============ updateExchangeRate Tests ============

    function test_UpdateExchangeRate_Success() public {
        uint256 newRate = INITIAL_EXCHANGE_RATE + 5e15; // 0.5% increase

        vm.prank(caller1);
        
        vm.expectEmit(true, false, false, true, address(exchangeRateUpdater));
        emit ExchangeRateUpdated(caller1, newRate);
        
        exchangeRateUpdater.updateExchangeRate(newRate);

        assertEq(stakedToken.exchangeRate(), newRate);
    }

    function test_UpdateExchangeRate_DecreasesAllowance() public {
        uint256 initialAllowance = exchangeRateUpdater.allowances(caller1);
        uint256 rateChange = 5e15; // 0.5% change
        uint256 newRate = INITIAL_EXCHANGE_RATE + rateChange;

        vm.prank(caller1);
        exchangeRateUpdater.updateExchangeRate(newRate);

        uint256 newAllowance = exchangeRateUpdater.allowances(caller1);
        assertEq(newAllowance, initialAllowance - rateChange);
    }

    function test_UpdateExchangeRate_RateIncrease() public {
        uint256 rateChange = 3e15; // 0.3% increase
        uint256 newRate = INITIAL_EXCHANGE_RATE + rateChange;

        vm.prank(caller1);
        exchangeRateUpdater.updateExchangeRate(newRate);

        assertEq(stakedToken.exchangeRate(), newRate);
    }

    function test_UpdateExchangeRate_RateDecrease() public {
        // First increase the rate so we can decrease it
        uint256 higherRate = INITIAL_EXCHANGE_RATE + 8e15; // 0.8% increase
        vm.prank(caller1);
        exchangeRateUpdater.updateExchangeRate(higherRate);

        // Reconfigure caller to reset allowance
        vm.prank(owner);
        exchangeRateUpdater.configureCaller(caller1, ALLOWANCE, INTERVAL);

        // Now decrease the rate
        uint256 lowerRate = higherRate - 3e15; // 0.3% decrease
        vm.prank(caller1);
        exchangeRateUpdater.updateExchangeRate(lowerRate);

        assertEq(stakedToken.exchangeRate(), lowerRate);
    }

    function test_UpdateExchangeRate_RevertWhen_NotCaller() public {
        vm.prank(nonCaller);
        vm.expectRevert("RateLimit: caller is not whitelisted");
        exchangeRateUpdater.updateExchangeRate(INITIAL_EXCHANGE_RATE + 100);
    }

    function test_UpdateExchangeRate_RevertWhen_ZeroRate() public {
        vm.prank(caller1);
        vm.expectRevert("ExchangeRateUpdater: new exchange rate must be greater than 0");
        exchangeRateUpdater.updateExchangeRate(0);
    }

    function test_UpdateExchangeRate_RevertWhen_SameRate() public {
        vm.prank(caller1);
        vm.expectRevert("ExchangeRateUpdater: exchange rate isn't new");
        exchangeRateUpdater.updateExchangeRate(INITIAL_EXCHANGE_RATE);
    }

    function test_UpdateExchangeRate_RevertWhen_ExceedsAllowance() public {
        // Try to update by more than the allowance
        uint256 excessiveChange = ALLOWANCE + 1;
        uint256 newRate = INITIAL_EXCHANGE_RATE + excessiveChange;

        vm.prank(caller1);
        vm.expectRevert("ExchangeRateUpdater: exchange rate update exceeds allowance");
        exchangeRateUpdater.updateExchangeRate(newRate);
    }

    function test_UpdateExchangeRate_MultipleUpdates() public {
        // First update
        uint256 rate1 = INITIAL_EXCHANGE_RATE + 3e15; // 0.3%
        vm.prank(caller1);
        exchangeRateUpdater.updateExchangeRate(rate1);
        assertEq(stakedToken.exchangeRate(), rate1);

        // Second update
        uint256 rate2 = rate1 + 3e15; // another 0.3%
        vm.prank(caller1);
        exchangeRateUpdater.updateExchangeRate(rate2);
        assertEq(stakedToken.exchangeRate(), rate2);
    }

    function test_UpdateExchangeRate_ExactAllowanceAmount() public {
        // Configure with specific allowance
        uint256 exactAllowance = 5e15; // 0.5%
        vm.prank(owner);
        exchangeRateUpdater.configureCaller(caller2, exactAllowance, INTERVAL);

        // Update by exactly the allowance amount
        uint256 newRate = INITIAL_EXCHANGE_RATE + exactAllowance;
        
        vm.prank(caller2);
        exchangeRateUpdater.updateExchangeRate(newRate);

        assertEq(stakedToken.exchangeRate(), newRate);
        assertEq(exchangeRateUpdater.allowances(caller2), 0);
    }

    // ============ Rate Limit Integration Tests ============

    function test_RateLimit_AllowanceReplenishesOverTime() public {
        // Use up most of the allowance (90%)
        uint256 rateChange = ALLOWANCE * 9 / 10; // 0.9% of allowance
        uint256 newRate = INITIAL_EXCHANGE_RATE + rateChange;
        
        vm.prank(caller1);
        exchangeRateUpdater.updateExchangeRate(newRate);

        uint256 remainingAllowance = exchangeRateUpdater.allowances(caller1);
        assertEq(remainingAllowance, ALLOWANCE / 10); // 10% remaining

        // Warp time and check estimated allowance
        vm.warp(block.timestamp + INTERVAL / 2);
        
        uint256 estimated = exchangeRateUpdater.estimatedAllowance(caller1);
        // Should have replenished about half
        assertGt(estimated, remainingAllowance);
    }

    function test_RateLimit_CanUpdateAfterReplenishment() public {
        // Use up all allowance
        uint256 rateChange = ALLOWANCE;
        uint256 newRate = INITIAL_EXCHANGE_RATE + rateChange;
        
        vm.prank(caller1);
        exchangeRateUpdater.updateExchangeRate(newRate);

        assertEq(exchangeRateUpdater.allowances(caller1), 0);

        // Try to update again - should fail
        vm.prank(caller1);
        vm.expectRevert("ExchangeRateUpdater: exchange rate update exceeds allowance");
        exchangeRateUpdater.updateExchangeRate(newRate + 1);

        // Warp full interval to replenish
        vm.warp(block.timestamp + INTERVAL);

        // Now should be able to update
        uint256 finalRate = newRate + 5e15; // 0.5% increase
        vm.prank(caller1);
        exchangeRateUpdater.updateExchangeRate(finalRate);

        assertEq(stakedToken.exchangeRate(), finalRate);
    }

    function test_RateLimit_ConfigureMultipleCallers() public {
        vm.startPrank(owner);
        exchangeRateUpdater.configureCaller(caller2, ALLOWANCE * 2, INTERVAL * 2);
        vm.stopPrank();

        assertTrue(exchangeRateUpdater.callers(caller1));
        assertTrue(exchangeRateUpdater.callers(caller2));
        assertEq(exchangeRateUpdater.maxAllowances(caller2), ALLOWANCE * 2);
    }

    function test_RateLimit_RemoveCaller() public {
        vm.prank(owner);
        exchangeRateUpdater.removeCaller(caller1);

        assertFalse(exchangeRateUpdater.callers(caller1));

        // Removed caller cannot update
        vm.prank(caller1);
        vm.expectRevert("RateLimit: caller is not whitelisted");
        exchangeRateUpdater.updateExchangeRate(INITIAL_EXCHANGE_RATE + 1e15);
    }

    // ============ Oracle Integration Tests ============

    function test_OracleIntegration_ExchangeRateUpdaterIsOracle() public view {
        assertEq(stakedToken.oracle(), address(exchangeRateUpdater));
    }

    function test_OracleIntegration_OnlyOracleCanUpdateToken() public {
        // Direct update should fail from non-oracle
        vm.prank(caller1);
        vm.expectRevert("StakedTokenV1: caller is not the oracle");
        stakedToken.updateExchangeRate(INITIAL_EXCHANGE_RATE + 1e15);
    }

    function test_OracleIntegration_UpdateThroughExchangeRateUpdater() public {
        uint256 newRate = INITIAL_EXCHANGE_RATE + 5e15; // 0.5% increase
        
        vm.prank(caller1);
        exchangeRateUpdater.updateExchangeRate(newRate);

        assertEq(stakedToken.exchangeRate(), newRate);
    }

    // ============ Ownership Tests ============

    function test_Ownership_TransferOwnership() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        exchangeRateUpdater.transferOwnership(newOwner);

        assertEq(exchangeRateUpdater.owner(), newOwner);
    }

    function test_Ownership_NewOwnerCanConfigureCallers() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        exchangeRateUpdater.transferOwnership(newOwner);

        vm.prank(newOwner);
        exchangeRateUpdater.configureCaller(caller2, ALLOWANCE, INTERVAL);

        assertTrue(exchangeRateUpdater.callers(caller2));
    }

    function test_Ownership_OldOwnerCannotConfigure() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        exchangeRateUpdater.transferOwnership(newOwner);

        vm.prank(owner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", owner));
        exchangeRateUpdater.configureCaller(caller2, ALLOWANCE, INTERVAL);
    }

    // ============ Edge Cases ============

    function test_EdgeCase_VerySmallRateChange() public {
        uint256 newRate = INITIAL_EXCHANGE_RATE + 1; // Minimum change

        vm.prank(caller1);
        exchangeRateUpdater.updateExchangeRate(newRate);

        assertEq(stakedToken.exchangeRate(), newRate);
    }

    function test_EdgeCase_LargeRateWithinAllowance() public {
        // Configure with larger allowance for this test
        uint256 largeAllowance = 1e18; // 100% rate change allowed
        vm.prank(owner);
        exchangeRateUpdater.configureCaller(caller2, largeAllowance, INTERVAL);

        uint256 largeRate = INITIAL_EXCHANGE_RATE + 5e17; // 50% increase
        
        vm.prank(caller2);
        exchangeRateUpdater.updateExchangeRate(largeRate);

        assertEq(stakedToken.exchangeRate(), largeRate);
    }

    function test_EdgeCase_RateChangeEqualsCurrentAllowance() public {
        uint256 allowance = exchangeRateUpdater.allowances(caller1);
        uint256 newRate = INITIAL_EXCHANGE_RATE + allowance;

        vm.prank(caller1);
        exchangeRateUpdater.updateExchangeRate(newRate);

        assertEq(exchangeRateUpdater.allowances(caller1), 0);
    }

    // ============ View Function Tests ============

    function test_ViewFunctions_TokenContract() public view {
        assertEq(exchangeRateUpdater.tokenContract(), address(stakedToken));
    }

    function test_ViewFunctions_CallerMappings() public view {
        assertTrue(exchangeRateUpdater.callers(caller1));
        assertEq(exchangeRateUpdater.maxAllowances(caller1), ALLOWANCE);
        assertEq(exchangeRateUpdater.intervals(caller1), INTERVAL);
    }

    // ============ Fuzz Tests ============

    function testFuzz_UpdateExchangeRate_ValidChanges(uint256 rateChange) public {
        // Bound rate change to valid range
        vm.assume(rateChange > 0 && rateChange <= ALLOWANCE);

        uint256 newRate = INITIAL_EXCHANGE_RATE + rateChange;

        vm.prank(caller1);
        exchangeRateUpdater.updateExchangeRate(newRate);

        assertEq(stakedToken.exchangeRate(), newRate);
    }

    function testFuzz_UpdateExchangeRate_AllowanceDecrease(uint256 rateChange) public {
        vm.assume(rateChange > 0 && rateChange <= ALLOWANCE);

        uint256 initialAllowance = exchangeRateUpdater.allowances(caller1);
        uint256 newRate = INITIAL_EXCHANGE_RATE + rateChange;

        vm.prank(caller1);
        exchangeRateUpdater.updateExchangeRate(newRate);

        assertEq(exchangeRateUpdater.allowances(caller1), initialAllowance - rateChange);
    }

    // ============ Integration Scenario Tests ============

    function test_Scenario_DailyRateUpdates() public {
        uint256 dailyChange = 2e15; // 0.2% per day (typical staking yield)
        uint256 currentRate = INITIAL_EXCHANGE_RATE;

        // Simulate 5 days of rate updates
        for (uint256 day = 0; day < 5; day++) {
            // Update rate
            currentRate += dailyChange;
            vm.prank(caller1);
            exchangeRateUpdater.updateExchangeRate(currentRate);
            assertEq(stakedToken.exchangeRate(), currentRate);

            // Advance one day to replenish
            vm.warp(block.timestamp + 1 days);
        }

        // Final rate should be initial + 5 * daily change
        assertEq(stakedToken.exchangeRate(), INITIAL_EXCHANGE_RATE + 5 * dailyChange);
    }

    function test_Scenario_MultipleCallersUpdating() public {
        // Configure second caller
        vm.prank(owner);
        exchangeRateUpdater.configureCaller(caller2, ALLOWANCE, INTERVAL);

        uint256 rate1 = INITIAL_EXCHANGE_RATE + 3e15; // 0.3%
        uint256 rate2 = rate1 + 2e15; // another 0.2%

        // First caller updates
        vm.prank(caller1);
        exchangeRateUpdater.updateExchangeRate(rate1);
        assertEq(stakedToken.exchangeRate(), rate1);

        // Second caller updates
        vm.prank(caller2);
        exchangeRateUpdater.updateExchangeRate(rate2);
        assertEq(stakedToken.exchangeRate(), rate2);
    }

    function test_Scenario_EmergencyRateUpdate() public {
        // Configure emergency caller with higher allowance
        address emergencyCaller = makeAddr("emergency");
        uint256 emergencyAllowance = 1e17; // 10% max change for emergencies
        
        vm.prank(owner);
        exchangeRateUpdater.configureCaller(emergencyCaller, emergencyAllowance, 1 hours);

        // Simulate emergency rate correction (5% adjustment)
        uint256 emergencyRate = INITIAL_EXCHANGE_RATE + 5e16;
        
        vm.prank(emergencyCaller);
        exchangeRateUpdater.updateExchangeRate(emergencyRate);

        assertEq(stakedToken.exchangeRate(), emergencyRate);
    }
}

/**
 * @title ExchangeRateUpdaterE2ETest
 * @notice End-to-end tests for the complete exchange rate update flow
 */
contract ExchangeRateUpdaterE2ETest is Test {
    ExchangeRateUpdater public exchangeRateUpdater;
    StakedTokenV1 public stakedToken;
    Proxy public proxy;

    address public admin;
    address public minter;
    address public receiver;
    address public oracleOwner;
    address public oracleCaller;

    uint256 public constant DECIMALS = 18;
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10 ** DECIMALS;
    uint256 public constant INITIAL_RATE = 1e18;
    uint256 public constant RATE_ALLOWANCE = 1e16; // ~1% rate change per day
    uint256 public constant RATE_INTERVAL = 1 days;

    function setUp() public {
        admin = makeAddr("admin");
        minter = makeAddr("minter");
        receiver = makeAddr("receiver");
        oracleOwner = makeAddr("oracleOwner");
        oracleCaller = makeAddr("oracleCaller");

        // Deploy StakedTokenV1
        StakedTokenV1 implementation = new StakedTokenV1();
        bytes memory initData = abi.encodeWithSelector(
            Token.initialize.selector,
            "OKX Staked ETH",
            "xBETH",
            admin,
            minter,
            receiver,
            MAX_SUPPLY
        );
        proxy = new Proxy(address(implementation), admin, initData);
        stakedToken = StakedTokenV1(address(proxy));

        // Deploy and configure ExchangeRateUpdater
        exchangeRateUpdater = new ExchangeRateUpdater(address(this));
        exchangeRateUpdater.initialize(oracleOwner, address(stakedToken));

        // Set oracleOwner as oracle first, in order to set the initial exchange rate
        vm.prank(admin);
        stakedToken.updateOracle(oracleOwner);

        // Set initial exchange rate
        vm.prank(oracleOwner);
        stakedToken.updateExchangeRate(INITIAL_RATE);

        // Set ExchangeRateUpdater as oracle
        vm.prank(admin);
        stakedToken.updateOracle(address(exchangeRateUpdater));

        // Configure caller with rate limit
        vm.prank(oracleOwner);
        exchangeRateUpdater.configureCaller(oracleCaller, RATE_ALLOWANCE, RATE_INTERVAL);
    }

    function test_E2E_CompleteRateUpdateFlow() public {
        // 1. Verify initial state
        assertEq(stakedToken.oracle(), address(exchangeRateUpdater));
        assertEq(stakedToken.exchangeRate(), INITIAL_RATE);
        assertTrue(exchangeRateUpdater.callers(oracleCaller));

        // 2. Update exchange rate (0.5% increase)
        uint256 rateChange = 5e15;
        uint256 newRate = INITIAL_RATE + rateChange;
        vm.prank(oracleCaller);
        exchangeRateUpdater.updateExchangeRate(newRate);

        // 3. Verify rate updated on token
        assertEq(stakedToken.exchangeRate(), newRate);

        // 4. Verify allowance decreased
        assertEq(exchangeRateUpdater.allowances(oracleCaller), RATE_ALLOWANCE - rateChange);
    }

    function test_E2E_RateLimitingPreventsExcessiveUpdates() public {
        // Update to use up all allowance
        uint256 newRate = INITIAL_RATE + RATE_ALLOWANCE;
        vm.prank(oracleCaller);
        exchangeRateUpdater.updateExchangeRate(newRate);

        // Cannot update again immediately
        vm.prank(oracleCaller);
        vm.expectRevert("ExchangeRateUpdater: exchange rate update exceeds allowance");
        exchangeRateUpdater.updateExchangeRate(newRate + 1);

        // After waiting, can update again
        vm.warp(block.timestamp + RATE_INTERVAL);
        
        vm.prank(oracleCaller);
        exchangeRateUpdater.updateExchangeRate(newRate + 5e15); // 0.5% more
    }

    function test_E2E_OwnershipAndAccessControl() public {
        // Only oracle owner can configure callers
        address newCaller = makeAddr("newCaller");
        
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", admin));
        exchangeRateUpdater.configureCaller(newCaller, RATE_ALLOWANCE, RATE_INTERVAL);

        // Oracle owner can configure
        vm.prank(oracleOwner);
        exchangeRateUpdater.configureCaller(newCaller, RATE_ALLOWANCE, RATE_INTERVAL);

        assertTrue(exchangeRateUpdater.callers(newCaller));
    }

    function test_E2E_ChangingOracle() public {
        // Create new oracle updater
        ExchangeRateUpdater newUpdater = new ExchangeRateUpdater(address(this));
        newUpdater.initialize(oracleOwner, address(stakedToken));

        // Admin changes oracle
        vm.prank(admin);
        stakedToken.updateOracle(address(newUpdater));

        // Old updater can no longer update
        vm.prank(oracleCaller);
        vm.expectRevert(); // Will fail because old updater is no longer oracle
        exchangeRateUpdater.updateExchangeRate(INITIAL_RATE + 5e15);

        // Configure caller on new updater
        vm.prank(oracleOwner);
        newUpdater.configureCaller(oracleCaller, RATE_ALLOWANCE, RATE_INTERVAL);

        // New updater can update
        uint256 newRate = INITIAL_RATE + 3e15; // 0.3% increase
        vm.prank(oracleCaller);
        newUpdater.updateExchangeRate(newRate);

        assertEq(stakedToken.exchangeRate(), newRate);
    }
}

