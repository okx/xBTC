// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {ExchangeRateUpdater} from "../contracts/ExchangeRateUpdater.sol";
import {StakedTokenV1} from "../contracts/StakedTokenV1.sol";
import {Token} from "../contracts/Token.sol";
import {Proxy} from "../contracts/Proxy.sol";

/**
 * @title StakedTokenV1IntegrationTest
 * @notice Integration tests for the StakedTokenV1 and ExchangeRateUpdater contract
 */
contract StakedTokenV1IntegrationTest is Test {
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
            Token.initialize.selector, "OKX Staked ETH", "xBETH", admin, minter, receiver, MAX_SUPPLY
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

    // ============ Integration Scenario Tests ============

    function test_Scenario_DailyRateUpdates() public {
        uint256 dailyChange = 2e15; // 0.2% per day
        uint256 currentRate = INITIAL_RATE;

        // Simulate 5 days of rate updates
        for (uint256 day = 0; day < 5; day++) {
            // Update rate
            currentRate += dailyChange;
            vm.prank(oracleCaller);
            exchangeRateUpdater.updateExchangeRate(currentRate);
            assertEq(stakedToken.exchangeRate(), currentRate);

            // Advance one day to replenish
            vm.warp(block.timestamp + 1 days);
        }

        // Final rate should be initial + 5 * daily change
        assertEq(stakedToken.exchangeRate(), INITIAL_RATE + 5 * dailyChange);
    }

    function test_Scenario_MultipleCallersUpdating() public {
        // Configure second caller
        vm.prank(oracleOwner);
        address caller2 = makeAddr("caller2");
        exchangeRateUpdater.configureCaller(caller2, RATE_ALLOWANCE, RATE_INTERVAL);

        uint256 rate1 = INITIAL_RATE + RATE_ALLOWANCE;
        uint256 rate2 = rate1 + RATE_ALLOWANCE;

        // First caller updates
        vm.prank(oracleCaller);
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

        vm.prank(oracleOwner);
        exchangeRateUpdater.configureCaller(emergencyCaller, emergencyAllowance, 1 hours);

        // Simulate emergency rate correction (5% adjustment)
        uint256 emergencyRate = INITIAL_RATE + emergencyAllowance;

        vm.prank(emergencyCaller);
        exchangeRateUpdater.updateExchangeRate(emergencyRate);

        assertEq(stakedToken.exchangeRate(), emergencyRate);
    }
}
