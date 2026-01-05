// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import {
    ProxyAdmin,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {xbtc} from "contracts/xbtc.sol";

/**
 * @title ForkTestTimelockUpgradeXBTC
 * @notice Fork test script to simulate timelock-controlled proxy upgrade on xLayer mainnet
 * @dev This script demonstrates:
 *      1. Forking xLayer mainnet
 *      2. Scheduling a timelock operation (upgrade proxy implementation)
 *      3. Fast-forwarding time 3 days past the timelock delay
 *      4. Executing the scheduled upgrade operation
 *      5. Verifying the implementation was upgraded successfully
 *
 * Usage:
 *   forge script scripts/ForkTestTimelock.UpgradeXBTC.s.sol:ForkTestTimelockUpgradeXBTC \
 *     --fork-url $XLAYER_RPC_URL \
 *     -vvvv
 *
 * Environment Variables Required:
 *   - TIMELOCK_ADDRESS: Address of the TimelockController
 *   - XBTC_PROXY_ADDRESS: Address of the xBTC proxy
 *   - NEW_XBTC_IMPLEMENTATION: Address of the new xBTC implementation (already deployed)
 *   - PRIVILEGED_ADDRESS: Address with PROPOSER_ROLE and EXECUTOR_ROLE in timelock
 */
contract ForkTestTimelockUpgradeXBTC is Script {
    // ==================== Configuration ====================

    // Deployed contract addresses on xLayer mainnet
    address public timelockAddress;
    address public xbtcProxyAddress;
    address public proxyAdminAddress;
    address public newImplementationAddress;

    // Test addresses
    address public proposer;
    address public executor;

    // Role constants
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    // Timelock operation parameters
    bytes32 public constant SALT = bytes32(0);
    bytes32 public constant PREDECESSOR = bytes32(0);
    uint256 public constant THREE_DAYS = 3 days;

    // Contract instances
    TimelockController public timelock;
    ProxyAdmin public proxyAdmin;
    xbtc public xbtcProxy;
    xbtc public newImplementation;
    
    // Reference implementation for bytecode comparison
    bytes public expectedBytecode;

    // Operation tracking
    bytes32 public operationId;
    uint256 public minDelay;
    address public oldImplementation;

    function setUp() public {
        // Load addresses from environment variables
        timelockAddress = vm.envAddress("TIMELOCK_ADDRESS");
        xbtcProxyAddress = vm.envAddress("XBTC_PROXY_ADDRESS");
        newImplementationAddress = vm.envAddress("NEW_XBTC_IMPLEMENTATION");

        // Initialize contract instances
        timelock = TimelockController(payable(timelockAddress));
        xbtcProxy = xbtc(xbtcProxyAddress);
        newImplementation = xbtc(newImplementationAddress);

        proposer = vm.envAddress("PRIVILEGED_ADDRESS");
        executor = proposer;

        console.log("=== Fork Test Configuration ===");
        console.log("Timelock Address:", timelockAddress);
        console.log("xBTC Proxy Address:", xbtcProxyAddress);
        console.log("New Implementation Address:", newImplementationAddress);
        console.log("Proposer/Executor:", proposer);
        console.log("");
    }

    function run() external {
        // Query current state
        queryCurrentState();

        console.log("\n=== Test Scenario: Upgrade xBTC Implementation via Timelock ===\n");
        testUpgradeImplementation();

        console.log("\n=== Fork Test Completed Successfully ===\n");
    }

    /**
     * @notice Query and display current state of contracts
     */
    function queryCurrentState() internal {
        console.log("=== Current State Query ===");

        // Query timelock configuration
        minDelay = timelock.getMinDelay();
        console.log("Timelock Min Delay (seconds):", minDelay);
        console.log("Timelock Min Delay (days):", minDelay / 1 days);

        // Check if proposer has PROPOSER_ROLE
        require(timelock.hasRole(PROPOSER_ROLE, proposer), "Proposer does not have PROPOSER_ROLE");

        // Check if executor has EXECUTOR_ROLE
        require(timelock.hasRole(EXECUTOR_ROLE, executor), "Executor does not have EXECUTOR_ROLE");

        // Check current xBTC version
        string memory currentVersion = xbtcProxy.version();
        console.log("Current xBTC Version:", currentVersion);

        // Check if contract is paused
        bool isPaused = xbtcProxy.paused();
        console.log("xBTC Contract Paused:", isPaused);

        console.log("");

        // ========== Get ProxyAdmin Address ==========
        console.log("=== ProxyAdmin Configuration ===");

        // Get ProxyAdmin address from ERC1967 storage slot
        bytes32 ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        bytes32 proxyAdminSlot = vm.load(xbtcProxyAddress, ADMIN_SLOT);
        proxyAdminAddress = address(uint160(uint256(proxyAdminSlot)));
        console.log("ProxyAdmin Contract Address:", proxyAdminAddress);

        // Initialize ProxyAdmin instance
        proxyAdmin = ProxyAdmin(proxyAdminAddress);

        // Check Timelock is the owner of ProxyAdmin
        address proxyAdminOwner = proxyAdmin.owner();
        require(proxyAdminOwner == timelockAddress, "FAILED: Timelock is not ProxyAdmin owner");

        // Get current implementation address
        bytes32 IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        bytes32 implementationSlot = vm.load(xbtcProxyAddress, IMPLEMENTATION_SLOT);
        oldImplementation = address(uint160(uint256(implementationSlot)));
        console.log("Current Implementation Address:", oldImplementation);

        console.log("");
    }

    /**
     * @notice Test upgrading xBTC implementation through timelock
     */
    function testUpgradeImplementation() internal {
        console.log("--- Step 1: Verify new xBTC implementation ---");

        console.log("New implementation address:", newImplementationAddress);
        
        // Check that the new implementation address has code
        require(newImplementationAddress.code.length > 0, "New implementation has no code");
        console.log("New implementation code size:", newImplementationAddress.code.length, "bytes");

        // Get the deployed bytecode
        bytes memory deployedBytecode = newImplementationAddress.code;
        console.log("Deployed bytecode size:", deployedBytecode.length, "bytes");

        // Generate expected bytecode by deploying a reference implementation
        xbtc referenceImpl = new xbtc();
        expectedBytecode = address(referenceImpl).code;
        console.log("Expected bytecode size:", expectedBytecode.length, "bytes");

        // Verify bytecode matches expected xbtc bytecode
        require(keccak256(deployedBytecode) == keccak256(expectedBytecode), "Bytecode verification failed - not a valid xbtc contract");

        // Verify new implementation is different from old
        console.log("Old version:", xbtcProxy.version());
        console.log("New version:", newImplementation.version());
        require(
            newImplementationAddress != oldImplementation,
            "New implementation same as old"
        );
        console.log("VERIFIED: New implementation is valid and different from current");

        console.log("\n--- Step 2: Prepare upgrade operation calldata ---");

        // Prepare the upgrade call: ProxyAdmin.upgradeAndCall(proxy, newImpl, data)
        bytes memory upgradeCalldata = abi.encodeCall(
            ProxyAdmin.upgradeAndCall,
            (
                ITransparentUpgradeableProxy(xbtcProxyAddress),
                newImplementationAddress,
                "" // empty data - no reinitialization needed
            )
        );

        console.log("Upgrade calldata:");
        console.logBytes(upgradeCalldata);

        // Calculate operation ID
        operationId = timelock.hashOperation(
            proxyAdminAddress, // target: ProxyAdmin contract
            0, // value
            upgradeCalldata, // data
            PREDECESSOR, // predecessor
            SALT // salt
        );

        console.log("Operation ID:");
        console.logBytes32(operationId);

        // Check if operation is already scheduled
        bool isScheduled = timelock.isOperationPending(operationId);
        console.log("Operation already scheduled:", isScheduled);

        console.log("\n--- Step 3: Schedule upgrade operation ---");

        if (!isScheduled) {
            // Impersonate proposer to schedule the operation
            vm.startPrank(proposer);

            console.log("\nSchedule Parameters:");
            console.log("  target:", proxyAdminAddress);
            console.log("  value: 0");
            console.log("  data:");
            console.logBytes(upgradeCalldata);
            console.log("  predecessor:");
            console.logBytes32(PREDECESSOR);
            console.log("  salt:");
            console.logBytes32(SALT);
            console.log("  delay:", minDelay, "seconds");

            try timelock.schedule(
                proxyAdminAddress,
                0,
                upgradeCalldata,
                PREDECESSOR,
                SALT,
                minDelay
            ) {
                console.log("SUCCESS: Operation scheduled");

                // Verify operation is now pending
                bool isPending = timelock.isOperationPending(operationId);
                console.log("Operation is pending:", isPending);

                // Get operation timestamp
                uint256 timestamp = timelock.getTimestamp(operationId);
                console.log("Operation ready at timestamp:", timestamp);
                console.log("Current timestamp:", block.timestamp);
                console.log(
                    "Time until ready:",
                    timestamp - block.timestamp,
                    "seconds"
                );
            } catch Error(string memory reason) {
                console.log("FAILED to schedule: ", reason);
                vm.stopPrank();
                revert("Schedule failed");
            } catch (bytes memory lowLevelData) {
                console.log("FAILED to schedule with low-level error");
                console.logBytes(lowLevelData);
                vm.stopPrank();
                revert("Schedule failed");
            }

            vm.stopPrank();
        } else {
            console.log("Operation already scheduled, skipping schedule step");
        }

        console.log("\n--- Step 4: Fast-forward time 3 days (past delay) ---");

        uint256 readyTimestamp = timelock.getTimestamp(operationId);
        uint256 currentTime = block.timestamp;

        if (currentTime < readyTimestamp) {
            // Fast forward exactly 3 days from now
            uint256 targetTime = currentTime + THREE_DAYS;
            console.log("Current timestamp:", currentTime);
            console.log("Ready timestamp:", readyTimestamp);
            console.log("Target timestamp (current + 3 days):", targetTime);
            console.log("Fast-forwarding:", THREE_DAYS, "seconds (3 days)");

            vm.warp(targetTime);

            console.log("New timestamp:", block.timestamp);
            console.log(
                "Time past ready:",
                block.timestamp - readyTimestamp,
                "seconds"
            );
        } else {
            console.log("Operation is already ready to execute");
            // Still fast forward 3 days to match requirement
            console.log("Fast-forwarding 3 days anyway...");
            vm.warp(currentTime + THREE_DAYS);
            console.log("New timestamp:", block.timestamp);
        }

        // Verify operation is ready
        bool isReady = timelock.isOperationReady(operationId);
        console.log("Operation is ready:", isReady);
        require(isReady, "Operation not ready after time warp");

        console.log("\n--- Step 5: Execute upgrade operation ---");

        // Get implementation before upgrade
        bytes32 IMPLEMENTATION_SLOT =
            bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        bytes32 implSlotBefore = vm.load(xbtcProxyAddress, IMPLEMENTATION_SLOT);
        address implBefore = address(uint160(uint256(implSlotBefore)));
        console.log("Implementation before upgrade:", implBefore);

        // Impersonate executor to execute the operation
        vm.startPrank(executor);

        try timelock.execute(
            proxyAdminAddress, 0, upgradeCalldata, PREDECESSOR, SALT
        ) {
            console.log("SUCCESS: Operation executed");
        } catch Error(string memory reason) {
            console.log("FAILED to execute: ", reason);
            vm.stopPrank();
            revert("Execute failed");
        } catch (bytes memory lowLevelData) {
            console.log("FAILED to execute with low-level error");
            console.logBytes(lowLevelData);
            vm.stopPrank();
            revert("Execute failed");
        }

        vm.stopPrank();

        console.log("\n--- Step 6: Verify upgrade result ---");

        // Get implementation after upgrade
        bytes32 implSlotAfter = vm.load(xbtcProxyAddress, IMPLEMENTATION_SLOT);
        address implAfter = address(uint160(uint256(implSlotAfter)));
        console.log("Implementation after upgrade:", implAfter);

        // Verify implementation changed
        require(implAfter != implBefore, "Implementation did not change");
        require(implAfter == newImplementationAddress, "Implementation does not match new deployment");

        // Verify operation is done
        require(timelock.isOperationDone(operationId), "Operation not done");

        // Verify proxy still works - check version
        string memory newVersion = xbtcProxy.version();
        console.log("New xBTC Version:", newVersion);

        // Verify proxy state is preserved (check if it's still paused/unpaused)
        bool isPausedAfter = xbtcProxy.paused();
        console.log("xBTC Contract Paused (after upgrade):", isPausedAfter);
    }
}

