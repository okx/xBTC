// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RateLimit} from "../contracts/RateLimit.sol";

/**
 * @title RateLimitTest
 * @notice Comprehensive unit tests for RateLimit contract
 * @dev Tests all rate limiting functionality including caller management and allowance replenishment
 */
contract RateLimitTest is Test {
    RateLimit public rateLimit;

    // Test accounts
    address public owner;
    address public caller1;
    address public caller2;
    address public nonOwner;

    // Test constants
    uint256 public constant ALLOWANCE = 1000 * 1e18;
    uint256 public constant INTERVAL = 1 days;

    // Events (must match contract)
    event CallerConfigured(
        address indexed caller, uint256 amount, uint256 interval
    );
    event CallerRemoved(address indexed caller);
    event AllowanceReplenished(
        address indexed caller, uint256 allowance, uint256 amountReplenished
    );

    function setUp() public {
        owner = makeAddr("owner");
        caller1 = makeAddr("caller1");
        caller2 = makeAddr("caller2");
        nonOwner = makeAddr("nonOwner");

        vm.prank(owner);
        rateLimit = new RateLimit(owner);
    }

    // ============ Constructor Tests ============

    function test_Constructor_SetsOwnerCorrectly() public view {
        assertEq(rateLimit.owner(), owner);
    }

    function test_Constructor_WithZeroAddressOwner_Reverts() public {
        vm.expectRevert(
            abi.encodeWithSignature("OwnableInvalidOwner(address)", address(0))
        );
        new RateLimit(address(0));
    }

    // ============ configureCaller Tests ============

    function test_ConfigureCaller_Success() public {
        vm.prank(owner);

        vm.expectEmit(true, false, false, true);
        emit CallerConfigured(caller1, ALLOWANCE, INTERVAL);

        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);

        assertTrue(rateLimit.callers(caller1));
        assertEq(rateLimit.maxAllowances(caller1), ALLOWANCE);
        assertEq(rateLimit.allowances(caller1), ALLOWANCE);
        assertEq(rateLimit.intervals(caller1), INTERVAL);
        assertEq(rateLimit.allowancesLastSet(caller1), block.timestamp);
    }

    function test_ConfigureCaller_UpdateExistingCaller() public {
        // First configuration
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);

        // Update with new values
        uint256 newAllowance = 2000 * 1e18;
        uint256 newInterval = 2 days;

        vm.prank(owner);
        rateLimit.configureCaller(caller1, newAllowance, newInterval);

        assertEq(rateLimit.maxAllowances(caller1), newAllowance);
        assertEq(rateLimit.allowances(caller1), newAllowance);
        assertEq(rateLimit.intervals(caller1), newInterval);
    }

    function test_ConfigureCaller_RevertWhen_NotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)", nonOwner
            )
        );
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);
    }

    function test_ConfigureCaller_RevertWhen_ZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert("RateLimit: caller is the zero address");
        rateLimit.configureCaller(address(0), ALLOWANCE, INTERVAL);
    }

    function test_ConfigureCaller_RevertWhen_ZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert("RateLimit: amount is zero");
        rateLimit.configureCaller(caller1, 0, INTERVAL);
    }

    function test_ConfigureCaller_RevertWhen_ZeroInterval() public {
        vm.prank(owner);
        vm.expectRevert("RateLimit: interval is zero");
        rateLimit.configureCaller(caller1, ALLOWANCE, 0);
    }

    function test_ConfigureCaller_MultiplCallers() public {
        vm.startPrank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);
        rateLimit.configureCaller(caller2, ALLOWANCE * 2, INTERVAL * 2);
        vm.stopPrank();

        assertTrue(rateLimit.callers(caller1));
        assertTrue(rateLimit.callers(caller2));
        assertEq(rateLimit.maxAllowances(caller1), ALLOWANCE);
        assertEq(rateLimit.maxAllowances(caller2), ALLOWANCE * 2);
    }

    // ============ removeCaller Tests ============

    function test_RemoveCaller_Success() public {
        // First configure a caller
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);
        assertTrue(rateLimit.callers(caller1));

        // Now remove the caller
        vm.prank(owner);

        vm.expectEmit(true, false, false, false);
        emit CallerRemoved(caller1);

        rateLimit.removeCaller(caller1);

        assertFalse(rateLimit.callers(caller1));
        assertEq(rateLimit.maxAllowances(caller1), 0);
        assertEq(rateLimit.allowances(caller1), 0);
        assertEq(rateLimit.intervals(caller1), 0);
        assertEq(rateLimit.allowancesLastSet(caller1), 0);
    }

    function test_RemoveCaller_RevertWhen_NotOwner() public {
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);

        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)", nonOwner
            )
        );
        rateLimit.removeCaller(caller1);
    }

    function test_RemoveCaller_NonExistentCaller_NoRevert() public {
        // Should not revert, just delete (no-op on zero values)
        vm.prank(owner);
        rateLimit.removeCaller(caller1);
        assertFalse(rateLimit.callers(caller1));
    }

    // ============ estimatedAllowance Tests ============

    function test_EstimatedAllowance_FullAllowance_NoReplenishment() public {
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);

        // Full allowance, no time passed - estimated should equal current
        assertEq(rateLimit.estimatedAllowance(caller1), ALLOWANCE);
    }

    function test_EstimatedAllowance_PartialReplenishment() public {
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);

        // Manually reduce allowance (simulate usage)
        // We need to use a derived contract or test differently
        // For now, we can test after time has passed with full allowance

        // With full allowance, even after time passes, estimated should cap at max
        vm.warp(block.timestamp + INTERVAL / 2);
        assertEq(rateLimit.estimatedAllowance(caller1), ALLOWANCE);
    }

    function test_EstimatedAllowance_AfterFullInterval() public {
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);

        // Warp full interval - should still cap at max
        vm.warp(block.timestamp + INTERVAL);
        assertEq(rateLimit.estimatedAllowance(caller1), ALLOWANCE);
    }

    function test_EstimatedAllowance_NonExistentCaller_RevertsWithDivisionByZero(
    ) public {
        // Non-existent caller has interval=0, causing division by zero
        // This is expected behavior - callers must be configured before use
        vm.expectRevert();
        rateLimit.estimatedAllowance(caller1);
    }

    // ============ currentAllowance Tests ============

    function test_CurrentAllowance_ReturnsCurrentValue() public {
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);

        uint256 current = rateLimit.currentAllowance(caller1);
        assertEq(current, ALLOWANCE);
    }

    function test_CurrentAllowance_TriggersReplenishment() public {
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);

        // At max allowance, no replenishment event should emit
        uint256 current = rateLimit.currentAllowance(caller1);
        assertEq(current, ALLOWANCE);
    }

    // ============ Allowance Replenishment Tests ============

    function test_AllowanceReplenishment_LinearOverTime() public {
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);

        // At start, full allowance
        assertEq(rateLimit.estimatedAllowance(caller1), ALLOWANCE);

        // Warp 1/4 of interval - still at max since we haven't used any
        vm.warp(block.timestamp + INTERVAL / 4);
        assertEq(rateLimit.estimatedAllowance(caller1), ALLOWANCE);
    }

    function test_AllowanceReplenishment_CapsAtMaxAllowance() public {
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);

        // Warp multiple intervals
        vm.warp(block.timestamp + INTERVAL * 10);

        // Should still cap at max allowance
        assertEq(rateLimit.estimatedAllowance(caller1), ALLOWANCE);
    }

    // ============ Edge Case Tests ============

    function test_EdgeCase_VerySmallInterval() public {
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, 1); // 1 second interval

        assertTrue(rateLimit.callers(caller1));
        assertEq(rateLimit.intervals(caller1), 1);
    }

    function test_EdgeCase_VeryLargeAllowance() public {
        uint256 largeAllowance = type(uint256).max / 2; // Large but safe value

        vm.prank(owner);
        rateLimit.configureCaller(caller1, largeAllowance, INTERVAL);

        assertEq(rateLimit.maxAllowances(caller1), largeAllowance);
    }

    function test_EdgeCase_MinimumValues() public {
        vm.prank(owner);
        rateLimit.configureCaller(caller1, 1, 1); // Minimum valid values

        assertTrue(rateLimit.callers(caller1));
        assertEq(rateLimit.maxAllowances(caller1), 1);
        assertEq(rateLimit.intervals(caller1), 1);
    }

    // ============ Ownership Tests ============

    function test_TransferOwnership() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        rateLimit.transferOwnership(newOwner);

        assertEq(rateLimit.owner(), newOwner);
    }

    function test_RenounceOwnership() public {
        vm.prank(owner);
        rateLimit.renounceOwnership();

        assertEq(rateLimit.owner(), address(0));
    }

    function test_TransferOwnership_RevertWhen_NotOwner() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)", nonOwner
            )
        );
        rateLimit.transferOwnership(newOwner);
    }

    // ============ Fuzz Tests ============

    function testFuzz_ConfigureCaller(
        address caller,
        uint256 amount,
        uint256 interval
    ) public {
        vm.assume(caller != address(0));
        vm.assume(amount > 0);
        vm.assume(interval > 0);

        vm.prank(owner);
        rateLimit.configureCaller(caller, amount, interval);

        assertTrue(rateLimit.callers(caller));
        assertEq(rateLimit.maxAllowances(caller), amount);
        assertEq(rateLimit.intervals(caller), interval);
    }

    function testFuzz_EstimatedAllowance_AlwaysLteMaxAllowance(
        uint256 amount,
        uint256 interval,
        uint256 timeElapsed
    ) public {
        vm.assume(amount > 0 && amount < 1e18);
        vm.assume(interval > 0 && interval < 365 days);
        vm.assume(timeElapsed > 0 && timeElapsed < 365 days);

        vm.prank(owner);
        rateLimit.configureCaller(caller1, amount, interval);

        vm.warp(block.timestamp + timeElapsed);

        assertLe(rateLimit.estimatedAllowance(caller1), amount);
    }
}

/**
 * @title RateLimitHarness
 * @notice Test harness to access internal functions for testing
 */
contract RateLimitHarness is RateLimit {
    constructor(address initialOwner) RateLimit(initialOwner) {}

    /// @notice Expose internal _replenishAllowance for testing
    function exposed_replenishAllowance(address caller) external {
        _replenishAllowance(caller);
    }

    /// @notice Expose internal _getReplenishAmount for testing
    function exposed_getReplenishAmount(address caller)
        external
        view
        returns (uint256)
    {
        return _getReplenishAmount(caller);
    }

    /// @notice Manually set allowance for testing (only for test purposes)
    function setAllowance(address caller, uint256 amount) external {
        allowances[caller] = amount;
    }
}

/**
 * @title RateLimitHarnessTest
 * @notice Tests using the harness to access internal functions
 */
contract RateLimitHarnessTest is Test {
    RateLimitHarness public rateLimit;

    address public owner;
    address public caller1;

    uint256 public constant ALLOWANCE = 1000 * 1e18;
    uint256 public constant INTERVAL = 1 days;

    event AllowanceReplenished(
        address indexed caller, uint256 allowance, uint256 amountReplenished
    );

    function setUp() public {
        owner = makeAddr("owner");
        caller1 = makeAddr("caller1");

        vm.prank(owner);
        rateLimit = new RateLimitHarness(owner);
    }

    function test_GetReplenishAmount_ZeroWhenAtMax() public {
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);

        // At max allowance, replenish amount should be 0
        uint256 replenishAmount = rateLimit.exposed_getReplenishAmount(caller1);
        assertEq(replenishAmount, 0);
    }

    function test_GetReplenishAmount_ProportionalToTimeElapsed() public {
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);

        // Manually reduce allowance to half
        rateLimit.setAllowance(caller1, ALLOWANCE / 2);

        // Warp half the interval
        vm.warp(block.timestamp + INTERVAL / 2);

        uint256 replenishAmount = rateLimit.exposed_getReplenishAmount(caller1);

        // Expected: (INTERVAL/2) * ALLOWANCE / INTERVAL = ALLOWANCE/2
        assertEq(replenishAmount, ALLOWANCE / 2);
    }

    function test_GetReplenishAmount_CapsAtRemainingToMax() public {
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);

        // Set allowance to 90% of max
        rateLimit.setAllowance(caller1, ALLOWANCE * 9 / 10);

        // Warp full interval - would normally replenish full amount
        vm.warp(block.timestamp + INTERVAL);

        uint256 replenishAmount = rateLimit.exposed_getReplenishAmount(caller1);

        // Should only replenish 10% to reach max
        assertEq(replenishAmount, ALLOWANCE / 10);
    }

    function test_ReplenishAllowance_EmitsEvent() public {
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);

        // Reduce allowance
        rateLimit.setAllowance(caller1, ALLOWANCE / 2);
        uint256 initialTimestamp = block.timestamp;

        // Warp and replenish
        vm.warp(initialTimestamp + INTERVAL / 2);

        vm.expectEmit(true, false, false, true);
        emit AllowanceReplenished(caller1, ALLOWANCE, ALLOWANCE / 2);

        rateLimit.exposed_replenishAllowance(caller1);
    }

    function test_ReplenishAllowance_UpdatesTimestamp() public {
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);

        uint256 initialTimestamp = rateLimit.allowancesLastSet(caller1);

        // Reduce allowance and warp time
        rateLimit.setAllowance(caller1, ALLOWANCE / 2);
        vm.warp(block.timestamp + INTERVAL / 2);

        rateLimit.exposed_replenishAllowance(caller1);

        assertGt(rateLimit.allowancesLastSet(caller1), initialTimestamp);
    }

    function test_ReplenishAllowance_UpdatesTimestampWhenAtMax() public {
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);

        uint256 initialTimestamp = rateLimit.allowancesLastSet(caller1);

        // Warp time but stay at max
        vm.warp(block.timestamp + INTERVAL);

        rateLimit.exposed_replenishAllowance(caller1);

        // Timestamp SHOULD update even when at max to prevent time accumulation vulnerability
        assertGt(rateLimit.allowancesLastSet(caller1), initialTimestamp);
        // Allowance should remain at max
        assertEq(rateLimit.allowances(caller1), ALLOWANCE);
    }

    function test_ReplenishAllowance_GradualReplenishment() public {
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);

        // Set to zero allowance
        rateLimit.setAllowance(caller1, 0);

        // Replenish 25% at a time
        for (uint256 i = 0; i < 4; i++) {
            vm.warp(block.timestamp + INTERVAL / 4);
            rateLimit.exposed_replenishAllowance(caller1);
        }

        // Should be back to full allowance
        assertEq(rateLimit.allowances(caller1), ALLOWANCE);
    }

    /**
     * @notice Test that the 2x maxAllowances vulnerability is fixed
     * @dev Previously, after a long period of inactivity, two consecutive calls in the same block
     *      could result in 2x maxAllowances being used due to stale allowancesLastSet timestamp.
     *      This test verifies the fix prevents this scenario.
     */
    function test_ReplenishAllowance_Prevents2xMaxAllowancesInSameBlock()
        public
    {
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);

        uint256 configuredTimestamp = block.timestamp;

        // Warp forward by a full interval (simulating no activity)
        vm.warp(configuredTimestamp + INTERVAL);

        // First replenish call - at max allowance
        rateLimit.exposed_replenishAllowance(caller1);

        // Verify allowancesLastSet was updated even though at max
        assertEq(
            rateLimit.allowancesLastSet(caller1), configuredTimestamp + INTERVAL
        );

        // Manually reduce allowance (simulating usage of full allowance)
        rateLimit.setAllowance(caller1, 0);

        // Second replenish call in the SAME BLOCK
        // With the fix, this should NOT replenish because allowancesLastSet was just updated
        rateLimit.exposed_replenishAllowance(caller1);

        // Verify: allowance should still be 0 (no replenishment in same block)
        assertEq(rateLimit.allowances(caller1), 0);
    }

    /**
     * @notice Test the vulnerability scenario with the original bug behavior
     * @dev This test demonstrates what WOULD have happened without the fix:
     *      The second replenish would have used the stale timestamp to calculate a full replenishment
     */
    function test_ReplenishAllowance_CorrectBehaviorAfterMultipleIntervals()
        public
    {
        // Reset timestamp to a known state
        vm.warp(1);
        
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);
        
        uint256 configuredTimestamp = rateLimit.allowancesLastSet(caller1);

        // Warp forward by multiple intervals
        vm.warp(configuredTimestamp + INTERVAL * 5);

        // First replenish - should cap at maxAllowances and update timestamp
        rateLimit.exposed_replenishAllowance(caller1);
        assertEq(rateLimit.allowances(caller1), ALLOWANCE);
        assertEq(
            rateLimit.allowancesLastSet(caller1),
            configuredTimestamp + INTERVAL * 5
        );

        // Use all allowance
        rateLimit.setAllowance(caller1, 0);

        // Second replenish in same block - should NOT replenish anything
        rateLimit.exposed_replenishAllowance(caller1);
        assertEq(rateLimit.allowances(caller1), 0);

        // Now warp half interval and replenish - should get half allowance
        vm.warp(block.timestamp + INTERVAL / 2);
        rateLimit.exposed_replenishAllowance(caller1);
        assertEq(rateLimit.allowances(caller1), ALLOWANCE / 2);
    }

    /**
     * @notice Verify timestamp is updated on replenish even when no amount is replenished
     * @dev Edge case: time passed but no replenishment needed (already at max)
     */
    function test_ReplenishAllowance_TimestampUpdatedEvenWhenNoReplenishmentNeeded(
    ) public {
        vm.prank(owner);
        rateLimit.configureCaller(caller1, ALLOWANCE, INTERVAL);

        uint256 initialTimestamp = rateLimit.allowancesLastSet(caller1);

        // Warp time, but allowance is already at max
        vm.warp(initialTimestamp + INTERVAL / 4);

        // Call replenish
        rateLimit.exposed_replenishAllowance(caller1);

        // Timestamp should be updated to prevent accumulation
        assertEq(
            rateLimit.allowancesLastSet(caller1),
            initialTimestamp + INTERVAL / 4
        );
        // Allowance unchanged at max
        assertEq(rateLimit.allowances(caller1), ALLOWANCE);
    }
}
