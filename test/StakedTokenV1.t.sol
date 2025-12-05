// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {StakedTokenV1} from "../contracts/StakedTokenV1.sol";
import {xToken} from "../contracts/xToken.sol";
import {Proxy} from "../contracts/Proxy.sol";

/**
 * @title StakedTokenV1Test
 * @notice Comprehensive tests for StakedTokenV1 to achieve 100% branch coverage
 */
contract StakedTokenV1Test is Test {
    StakedTokenV1 public stakedToken;
    Proxy public proxy;

    address public admin;
    address public minter;
    address public receiver;
    address public oracle;

    uint256 public constant DECIMALS = 18;
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10 ** DECIMALS;

    event OracleUpdated(address indexed newOracle);
    event ExchangeRateUpdated(address indexed oracle, uint256 newExchangeRate);

    function setUp() public {
        admin = makeAddr("admin");
        minter = makeAddr("minter");
        receiver = makeAddr("receiver");
        oracle = makeAddr("oracle");

        // Deploy StakedTokenV1 implementation
        StakedTokenV1 implementation = new StakedTokenV1();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            xToken.initialize.selector,
            "Staked Token",
            "STK",
            admin,
            minter,
            receiver,
            MAX_SUPPLY
        );

        // Deploy proxy
        proxy = new Proxy(address(implementation), admin, initData);
        stakedToken = StakedTokenV1(address(proxy));

        // Set oracle
        vm.prank(admin);
        stakedToken.updateOracle(oracle);
    }

    // ============ updateOracle Tests ============

    function test_UpdateOracle_Success() public {
        address newOracle = makeAddr("newOracle");

        vm.expectEmit(true, false, false, false);
        emit OracleUpdated(newOracle);

        vm.prank(admin);
        stakedToken.updateOracle(newOracle);

        assertEq(stakedToken.oracle(), newOracle);
    }

    function test_UpdateOracle_RevertWhen_ZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("StakedTokenV1: oracle is the zero address");
        stakedToken.updateOracle(address(0));
    }

    function test_UpdateOracle_RevertWhen_SameOracle() public {
        vm.prank(admin);
        vm.expectRevert("StakedTokenV1: new oracle is already the oracle");
        stakedToken.updateOracle(oracle);
    }

    function test_UpdateOracle_RevertWhen_NotAdmin() public {
        vm.prank(minter);
        vm.expectRevert();
        stakedToken.updateOracle(makeAddr("newOracle"));
    }

    // ============ updateExchangeRate Tests ============

    function test_UpdateExchangeRate_Success() public {
        uint256 newRate = 1.05e18;

        vm.expectEmit(true, false, false, true);
        emit ExchangeRateUpdated(oracle, newRate);

        vm.prank(oracle);
        stakedToken.updateExchangeRate(newRate);

        assertEq(stakedToken.exchangeRate(), newRate);
    }

    function test_UpdateExchangeRate_RevertWhen_ZeroRate() public {
        vm.prank(oracle);
        vm.expectRevert("StakedTokenV1: new exchange rate cannot be 0");
        stakedToken.updateExchangeRate(0);
    }

    function test_UpdateExchangeRate_RevertWhen_NotOracle() public {
        vm.prank(minter);
        vm.expectRevert("StakedTokenV1: caller is not the oracle");
        stakedToken.updateExchangeRate(1e18);
    }

    // ============ View Functions Tests ============

    function test_Oracle_ReturnsCorrectAddress() public view {
        assertEq(stakedToken.oracle(), oracle);
    }

    function test_ExchangeRate_ReturnsZeroInitially() public {
        // Create fresh instance without setting rate
        StakedTokenV1 implementation = new StakedTokenV1();
        bytes memory initData = abi.encodeWithSelector(
            xToken.initialize.selector,
            "Staked Token",
            "STK",
            admin,
            minter,
            receiver,
            MAX_SUPPLY
        );
        Proxy freshProxy = new Proxy(address(implementation), admin, initData);
        StakedTokenV1 freshToken = StakedTokenV1(address(freshProxy));

        assertEq(freshToken.exchangeRate(), 0);
    }

    // ============ Fuzz Tests ============

    function testFuzz_UpdateExchangeRate_ValidRate(uint256 rate) public {
        vm.assume(rate > 0);

        vm.prank(oracle);
        stakedToken.updateExchangeRate(rate);

        assertEq(stakedToken.exchangeRate(), rate);
    }
}
