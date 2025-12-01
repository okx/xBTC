// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title ForkTestTimelockUpdateMinDelay
 * @notice Fork test script to simulate updating timelock minimum delay through timelock itself
 * @dev This script demonstrates:
 *      1. Forking xLayer mainnet
 *      2. Scheduling a timelock operation to update its own minDelay
 *      3. Fast-forwarding time past the current timelock delay
 *      4. Executing the scheduled operation
 *      5. Verifying the new minDelay is set
 *
 * Usage:
 *   forge script scripts/ForkTestTimelock.UpdateMinDelay.s.sol:ForkTestTimelockUpdateMinDelay \
 *     --fork-url $XLAYER_RPC_URL \
 *     -vvvv
 */
contract ForkTestTimelockUpdateMinDelay is Script {
    // ==================== Configuration ====================

    // Deployed contract addresses on xLayer mainnet
    address public timelockAddress;

    // Test addresses
    address public proposer;
    address public executor;

    // Role constants
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    // Timelock operation parameters
    bytes32 public constant SALT = bytes32(0);
    bytes32 public constant PREDECESSOR = bytes32(0);

    // Contract instances
    TimelockController public timelock;

    // Operation tracking
    bytes32 public operationId;
    uint256 public currentMinDelay;
    uint256 public newMinDelay;

    function setUp() public {
        // Load addresses from environment variables
        timelockAddress = vm.envAddress("TIMELOCK_ADDRESS");

        // Initialize contract instances
        timelock = TimelockController(payable(timelockAddress));

        proposer = vm.envAddress("PRIVILEGED_ADDRESS");
        executor = proposer;

        // Set new minimum delay (e.g., 2 days = 172800 seconds)
        // You can override this via environment variable
        try vm.envUint("NEW_MIN_DELAY") returns (uint256 delay) {
            newMinDelay = delay;
        } catch {
            newMinDelay = 7 days; // Default value
        }

        console.log("=== Fork Test Configuration ===");
        console.log("Timelock Address:", timelockAddress);
        console.log("Proposer/Executor:", proposer);
        console.log("New Min Delay:", newMinDelay);
        console.log("");
    }

    function run() external {
        // Query current state
        queryCurrentState();

        console.log("\n=== Test Scenario: Update MinDelay via Timelock ===\n");
        testUpdateMinDelay();

        console.log("\n=== Fork Test Completed Successfully ===\n");
    }

    /**
     * @notice Query and display current state of timelock
     */
    function queryCurrentState() internal {
        console.log("=== Current State Query ===");

        // Query timelock configuration
        currentMinDelay = timelock.getMinDelay();
        console.log("Current Timelock Min Delay:", currentMinDelay);

        // Check if proposer has PROPOSER_ROLE
        bool isProposer = timelock.hasRole(PROPOSER_ROLE, proposer);
        console.log("Is Proposer:", isProposer);

        // Check if executor has EXECUTOR_ROLE
        bool isExecutor = timelock.hasRole(EXECUTOR_ROLE, executor);
        console.log("Is Executor:", isExecutor);

        console.log("");
    }

    /**
     * @notice Test updating minDelay through timelock
     */
    function testUpdateMinDelay() internal {
        console.log("--- Step 1: Check current minDelay ---");
        uint256 minDelayBefore = timelock.getMinDelay();
        console.log("MinDelay before:", minDelayBefore);

        if (minDelayBefore == newMinDelay) {
            console.log("SKIPPED: MinDelay is already set to the target value");
            return;
        }

        console.log("\n--- Step 2: Prepare operation calldata ---");

        // Prepare the call: updateDelay(newMinDelay)
        // Note: updateDelay can only be called by the timelock itself
        bytes memory updateDelayCalldata = abi.encodeWithSelector(TimelockController.updateDelay.selector, newMinDelay);

        console.log("Calldata (updateDelay):");
        console.logBytes(updateDelayCalldata);

        // Calculate operation ID
        // The target is the timelock itself
        operationId = timelock.hashOperation(
            timelockAddress, // target: timelock itself
            0, // value
            updateDelayCalldata, // data
            PREDECESSOR, // predecessor
            SALT // salt
        );

        console.log("Operation ID:");
        console.logBytes32(operationId);

        // Check if operation is already scheduled
        bool isScheduled = timelock.isOperationPending(operationId);
        console.log("Operation already scheduled:", isScheduled);

        console.log("\n--- Step 3: Schedule operation ---");

        if (!isScheduled) {
            // Impersonate proposer to schedule the operation
            vm.startPrank(proposer);

            console.log("\nSchedule Parameters:");
            console.log("  target:", timelockAddress);
            console.log("  value: 0");
            console.log("  data:");
            console.logBytes(updateDelayCalldata);
            console.log("  predecessor:");
            console.logBytes32(PREDECESSOR);
            console.log("  salt:");
            console.logBytes32(SALT);
            console.log("  delay:", currentMinDelay);

            try timelock.schedule(timelockAddress, 0, updateDelayCalldata, PREDECESSOR, SALT, currentMinDelay) {
                console.log("SUCCESS: Operation scheduled");

                // Verify operation is now pending
                bool isPending = timelock.isOperationPending(operationId);
                console.log("Operation is pending:", isPending);

                // Get operation timestamp
                uint256 timestamp = timelock.getTimestamp(operationId);
                console.log("Operation ready at timestamp:", timestamp);
                console.log("Current timestamp:", block.timestamp);
            } catch Error(string memory reason) {
                console.log("FAILED to schedule: ", reason);
                vm.stopPrank();
                return;
            } catch (bytes memory lowLevelData) {
                console.log("FAILED to schedule with low-level error");
                console.logBytes(lowLevelData);
                vm.stopPrank();
                return;
            }

            vm.stopPrank();
        } else {
            console.log("Operation already scheduled, skipping schedule step");
        }

        console.log("\n--- Step 4: Fast-forward time past delay ---");

        uint256 readyTimestamp = timelock.getTimestamp(operationId);
        uint256 currentTime = block.timestamp;

        if (currentTime < readyTimestamp) {
            uint256 timeToWarp = readyTimestamp - currentTime + 1;
            console.log("Warping forward by:", timeToWarp, "seconds");
            vm.warp(readyTimestamp + 1);
            console.log("New timestamp:", block.timestamp);
        } else {
            console.log("Operation is already ready to execute");
        }

        // Verify operation is ready
        bool isReady = timelock.isOperationReady(operationId);
        console.log("Operation is ready:", isReady);

        console.log("\n--- Step 5: Execute operation ---");

        // Impersonate executor to execute the operation
        vm.startPrank(executor);

        try timelock.execute(timelockAddress, 0, updateDelayCalldata, PREDECESSOR, SALT) {
            console.log("SUCCESS: Operation executed");
        } catch Error(string memory reason) {
            console.log("FAILED to execute: ", reason);
            vm.stopPrank();
            return;
        } catch (bytes memory lowLevelData) {
            console.log("FAILED to execute with low-level error");
            console.logBytes(lowLevelData);
            vm.stopPrank();
            return;
        }

        vm.stopPrank();

        console.log("\n--- Step 6: Verify result ---");

        // Check if minDelay has been updated
        uint256 minDelayAfter = timelock.getMinDelay();
        console.log("MinDelay before:", minDelayBefore);
        console.log("MinDelay after:", minDelayAfter);
        console.log("Expected new minDelay:", newMinDelay);

        // Verify operation is done
        bool isDone = timelock.isOperationDone(operationId);
        console.log("Operation is done:", isDone);

        if (minDelayAfter == newMinDelay && isDone) {
            console.log("\nTEST PASSED: MinDelay updated successfully via timelock");
        } else {
            console.log("\nTEST FAILED: MinDelay not updated correctly or operation not marked as done");
        }
    }
}
