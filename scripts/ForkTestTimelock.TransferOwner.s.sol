// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {xToken} from "../contracts/xToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ForkTestTimelockTransferOwner
 * @notice Fork test script for ROUND-TRIP ownership transfer test
 * @dev This script demonstrates:
 *      1. Transfer xBTC DEFAULT_ADMIN_ROLE from PRIVILEGED_ADDRESS to TimelockController
 *      2. Transfer ProxyAdmin ownership from PRIVILEGED_ADDRESS to TimelockController
 *      3. Transfer xBTC DEFAULT_ADMIN_ROLE from TimelockController back to PRIVILEGED_ADDRESS
 *      4. Transfer ProxyAdmin ownership from TimelockController back to PRIVILEGED_ADDRESS
 *
 * Usage:
 *   forge script scripts/ForkTestTimelockTransferOwner.s.sol:ForkTestTimelockTransferOwner \
 *     --fork-url $XLAYER_RPC_URL \
 *     --broadcast \
 *     -vvvv
 */
contract ForkTestTimelockTransferOwner is Script {
    // ==================== Configuration ====================

    // Deployed contract addresses on xLayer mainnet
    address public timelockAddress;
    address public xbtcProxyAddress;
    address public proxyAdminAddress;

    // Current admin address (PRIVILEGED_ADDRESS) for round-trip test
    address public currentAdmin;

    // Test addresses for timelock operations
    address public proposer;
    address public executor;

    // Role constants
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");

    // Timelock operation parameters
    bytes32 public constant SALT = bytes32(0);
    bytes32 public constant PREDECESSOR = bytes32(0);

    // Contract instances
    TimelockController public timelock;
    xToken public xbtcProxy;
    ProxyAdmin public proxyAdmin;

    // Operation tracking
    uint256 public minDelay;

    function setUp() public {
        // Load addresses from environment variables
        timelockAddress = vm.envAddress("TIMELOCK_ADDRESS");
        xbtcProxyAddress = vm.envAddress("XBTC_PROXY_ADDRESS");
        proxyAdminAddress = vm.envAddress("XBTC_PROXY_ADMIN_ADDRESS");
        currentAdmin = vm.envAddress("PRIVILEGED_ADDRESS");

        // Initialize contract instances
        timelock = TimelockController(payable(timelockAddress));
        xbtcProxy = xToken(xbtcProxyAddress);
        proxyAdmin = ProxyAdmin(proxyAdminAddress);

        // For timelock operations, use currentAdmin as proposer/executor
        proposer = currentAdmin;
        executor = currentAdmin;

        console.log("=== Fork Test Configuration ===");
        console.log("Timelock Address:", timelockAddress);
        console.log("xBTC Proxy Address:", xbtcProxyAddress);
        console.log("ProxyAdmin Address:", proxyAdminAddress);
        console.log("Current Admin (Privileged Address):", currentAdmin);
        console.log("");
    }

    function run() external {
        // Query current state
        queryCurrentState();

        console.log("\n=== PHASE 1: Transfer TO Timelock ===\n");

        // Test Scenario 1: Transfer xBTC DEFAULT_ADMIN_ROLE to Timelock
        console.log("\n=== Test Scenario 1: Transfer xBTC DEFAULT_ADMIN_ROLE to Timelock ===\n");
        testTransferDefaultAdminRoleToTimelock();

        // Test Scenario 2: Transfer ProxyAdmin Ownership to Timelock
        console.log("\n=== Test Scenario 2: Transfer ProxyAdmin Ownership to Timelock ===\n");
        testTransferProxyAdminOwnershipToTimelock();

        console.log("\n=== PHASE 2: Transfer BACK to Privileged Address ===\n");

        // Test Scenario 3: Transfer xBTC DEFAULT_ADMIN_ROLE back to Privileged Address
        console.log("\n=== Test Scenario 3: Transfer xBTC DEFAULT_ADMIN_ROLE back to Privileged Address ===\n");
        testTransferDefaultAdminRoleFromTimelock();

        // Test Scenario 4: Transfer ProxyAdmin Ownership back to Privileged Address
        console.log("\n=== Test Scenario 4: Transfer ProxyAdmin Ownership back to Privileged Address ===\n");
        testTransferProxyAdminOwnershipFromTimelock();

        console.log("\n=== Round-Trip Test Completed Successfully ===\n");
    }

    /**
     * @notice Query and display current state of contracts
     */
    function queryCurrentState() internal {
        console.log("=== Current State Query ===");

        // Query timelock configuration
        minDelay = timelock.getMinDelay();
        console.log("Timelock Min Delay:", minDelay);

        // Check if proposer has PROPOSER_ROLE
        bool isProposer = timelock.hasRole(PROPOSER_ROLE, proposer);
        console.log("Proposer has PROPOSER_ROLE:", isProposer);

        // Check if executor has EXECUTOR_ROLE
        bool isExecutor = timelock.hasRole(EXECUTOR_ROLE, executor);
        console.log("Executor has EXECUTOR_ROLE:", isExecutor);

        // Check current admin role status
        bool currentAdminHasRole = xbtcProxy.hasRole(DEFAULT_ADMIN_ROLE, currentAdmin);
        bool timelockHasAdmin = xbtcProxy.hasRole(DEFAULT_ADMIN_ROLE, timelockAddress);
        console.log("Current Admin has DEFAULT_ADMIN_ROLE:", currentAdminHasRole);
        console.log("Timelock has DEFAULT_ADMIN_ROLE:", timelockHasAdmin);

        // Check ProxyAdmin ownership
        address owner = proxyAdmin.owner();
        console.log("ProxyAdmin current owner:", owner);

        console.log("");
    }

    /**
     * @notice Test transferring DEFAULT_ADMIN_ROLE from currentAdmin to Timelock
     */
    function testTransferDefaultAdminRoleToTimelock() internal {
        console.log("--- Step 1: Check current DEFAULT_ADMIN_ROLE status ---");
        bool currentAdminHasRole = xbtcProxy.hasRole(DEFAULT_ADMIN_ROLE, currentAdmin);
        bool timelockHasRole = xbtcProxy.hasRole(DEFAULT_ADMIN_ROLE, timelockAddress);
        console.log("Current Admin has DEFAULT_ADMIN_ROLE:", currentAdminHasRole);
        console.log("Timelock has DEFAULT_ADMIN_ROLE:", timelockHasRole);

        if (!currentAdminHasRole) {
            console.log("SKIPPED: Current Admin doesn't have DEFAULT_ADMIN_ROLE");
            return;
        }

        if (timelockHasRole) {
            console.log("SKIPPED: Timelock already has DEFAULT_ADMIN_ROLE");
            return;
        }

        console.log("\n--- Step 2: Grant DEFAULT_ADMIN_ROLE to Timelock ---");
        console.log("(Direct call by currentAdmin, no timelock needed)");

        vm.startPrank(currentAdmin);

        try xbtcProxy.grantRole(DEFAULT_ADMIN_ROLE, timelockAddress) {
            console.log("SUCCESS: Granted DEFAULT_ADMIN_ROLE to Timelock");
        } catch Error(string memory reason) {
            console.log("FAILED to grant role: ", reason);
            vm.stopPrank();
            return;
        } catch (bytes memory lowLevelData) {
            console.log("FAILED to grant role with low-level error");
            console.logBytes(lowLevelData);
            vm.stopPrank();
            return;
        }

        console.log("\n--- Step 3: Revoke DEFAULT_ADMIN_ROLE from currentAdmin ---");
        console.log("(Direct call by currentAdmin, no timelock needed)");

        try xbtcProxy.revokeRole(DEFAULT_ADMIN_ROLE, currentAdmin) {
            console.log("SUCCESS: Revoked DEFAULT_ADMIN_ROLE from currentAdmin");
        } catch Error(string memory reason) {
            console.log("FAILED to revoke role: ", reason);
            vm.stopPrank();
            return;
        } catch (bytes memory lowLevelData) {
            console.log("FAILED to revoke role with low-level error");
            console.logBytes(lowLevelData);
            vm.stopPrank();
            return;
        }

        vm.stopPrank();

        console.log("\n--- Step 4: Verify result ---");

        bool currentAdminHasRoleAfter = xbtcProxy.hasRole(DEFAULT_ADMIN_ROLE, currentAdmin);
        bool timelockHasRoleAfter = xbtcProxy.hasRole(DEFAULT_ADMIN_ROLE, timelockAddress);
        console.log("Current Admin has DEFAULT_ADMIN_ROLE after:", currentAdminHasRoleAfter);
        console.log("Timelock has DEFAULT_ADMIN_ROLE after:", timelockHasRoleAfter);

        if (!currentAdminHasRoleAfter && timelockHasRoleAfter) {
            console.log("\nTEST PASSED: DEFAULT_ADMIN_ROLE transferred successfully");
        } else {
            console.log("\nTEST FAILED: DEFAULT_ADMIN_ROLE transfer incomplete");
        }
    }

    /**
     * @notice Test transferring ProxyAdmin ownership from currentAdmin to Timelock
     */
    function testTransferProxyAdminOwnershipToTimelock() internal {
        console.log("--- Step 1: Check current ProxyAdmin owner ---");
        address owner = proxyAdmin.owner();
        console.log("Current ProxyAdmin owner:", owner);

        if (owner != currentAdmin) {
            console.log("SKIPPED: Current Admin is not the current owner");
            return;
        }

        if (owner == timelockAddress) {
            console.log("SKIPPED: Timelock is already the owner");
            return;
        }

        console.log("\n--- Step 2: Transfer ownership to Timelock ---");
        console.log("(Direct call by currentAdmin, no timelock needed)");

        vm.startPrank(currentAdmin);

        try proxyAdmin.transferOwnership(timelockAddress) {
            console.log("SUCCESS: Transferred ProxyAdmin ownership to Timelock");
        } catch Error(string memory reason) {
            console.log("FAILED to transfer ownership: ", reason);
            vm.stopPrank();
            return;
        } catch (bytes memory lowLevelData) {
            console.log("FAILED to transfer ownership with low-level error");
            console.logBytes(lowLevelData);
            vm.stopPrank();
            return;
        }

        vm.stopPrank();

        console.log("\n--- Step 3: Verify result ---");

        address newOwner = proxyAdmin.owner();
        console.log("New ProxyAdmin owner:", newOwner);

        if (newOwner == timelockAddress) {
            console.log("\nTEST PASSED: ProxyAdmin ownership transferred successfully");
        } else {
            console.log("\nTEST FAILED: ProxyAdmin ownership not transferred");
        }
    }

    /**
     * @notice Test transferring DEFAULT_ADMIN_ROLE from Timelock back to currentAdmin
     */
    function testTransferDefaultAdminRoleFromTimelock() internal {
        console.log("--- Step 1: Check current DEFAULT_ADMIN_ROLE status ---");
        bool timelockHasRole = xbtcProxy.hasRole(DEFAULT_ADMIN_ROLE, timelockAddress);
        bool currentAdminHasRole = xbtcProxy.hasRole(DEFAULT_ADMIN_ROLE, currentAdmin);
        console.log("Timelock has DEFAULT_ADMIN_ROLE:", timelockHasRole);
        console.log("Current Admin has DEFAULT_ADMIN_ROLE:", currentAdminHasRole);

        if (!timelockHasRole) {
            console.log("SKIPPED: Timelock doesn't have DEFAULT_ADMIN_ROLE");
            return;
        }

        if (currentAdminHasRole) {
            console.log("SKIPPED: Current Admin already has DEFAULT_ADMIN_ROLE");
            return;
        }

        console.log("\n--- Step 2: Grant DEFAULT_ADMIN_ROLE to currentAdmin via Timelock ---");

        // Prepare the call to grant role
        bytes memory grantRoleCalldata =
            abi.encodeCall(IAccessControl.grantRole, (DEFAULT_ADMIN_ROLE, currentAdmin));

        bytes32 grantOperationId = timelock.hashOperation(xbtcProxyAddress, 0, grantRoleCalldata, PREDECESSOR, SALT);

        console.log("Grant Operation ID:");
        console.logBytes32(grantOperationId);

        // Check if operation is already scheduled
        bool isGrantScheduled = timelock.isOperationPending(grantOperationId);
        console.log("Grant operation already scheduled:", isGrantScheduled);

        if (!isGrantScheduled) {
            vm.startPrank(proposer);

            try timelock.schedule(xbtcProxyAddress, 0, grantRoleCalldata, PREDECESSOR, SALT, minDelay) {
                console.log("SUCCESS: Grant role operation scheduled");

                bool isPending = timelock.isOperationPending(grantOperationId);
                console.log("Operation is pending:", isPending);

                uint256 timestamp = timelock.getTimestamp(grantOperationId);
                console.log("Operation ready at timestamp:", timestamp);
            } catch Error(string memory reason) {
                console.log("FAILED to schedule grant: ", reason);
                vm.stopPrank();
                return;
            } catch (bytes memory lowLevelData) {
                console.log("FAILED to schedule grant with low-level error");
                console.logBytes(lowLevelData);
                vm.stopPrank();
                return;
            }

            vm.stopPrank();
        } else {
            console.log("Grant operation already scheduled, skipping schedule step");
        }

        console.log("\n--- Step 3: Fast-forward time past delay ---");

        uint256 readyTimestamp = timelock.getTimestamp(grantOperationId);
        uint256 currentTime = block.timestamp;

        if (currentTime < readyTimestamp) {
            uint256 timeToWarp = readyTimestamp - currentTime + 1;
            console.log("Warping forward by:", timeToWarp, "seconds");
            vm.warp(readyTimestamp + 1);
            console.log("New timestamp:", block.timestamp);
        } else {
            console.log("Operation is already ready to execute");
        }

        bool isReady = timelock.isOperationReady(grantOperationId);
        console.log("Operation is ready:", isReady);

        console.log("\n--- Step 4: Execute grant role operation ---");

        vm.startPrank(executor);

        try timelock.execute(xbtcProxyAddress, 0, grantRoleCalldata, PREDECESSOR, SALT) {
            console.log("SUCCESS: Grant role operation executed");
        } catch Error(string memory reason) {
            console.log("FAILED to execute grant: ", reason);
            vm.stopPrank();
            return;
        } catch (bytes memory lowLevelData) {
            console.log("FAILED to execute grant with low-level error");
            console.logBytes(lowLevelData);
            vm.stopPrank();
            return;
        }

        vm.stopPrank();

        console.log("\n--- Step 5: Revoke DEFAULT_ADMIN_ROLE from Timelock ---");
        console.log("(Direct call by currentAdmin, who now has the role)");

        // Now that currentAdmin has DEFAULT_ADMIN_ROLE, they can directly revoke Timelock's role
        vm.startPrank(currentAdmin);

        try xbtcProxy.revokeRole(DEFAULT_ADMIN_ROLE, timelockAddress) {
            console.log("SUCCESS: Revoked DEFAULT_ADMIN_ROLE from Timelock");
        } catch Error(string memory reason) {
            console.log("FAILED to revoke role: ", reason);
            vm.stopPrank();
            return;
        } catch (bytes memory lowLevelData) {
            console.log("FAILED to revoke role with low-level error");
            console.logBytes(lowLevelData);
            vm.stopPrank();
            return;
        }

        vm.stopPrank();

        console.log("\n--- Step 6: Verify result ---");

        bool timelockHasRoleAfter = xbtcProxy.hasRole(DEFAULT_ADMIN_ROLE, timelockAddress);
        bool currentAdminHasRoleAfter = xbtcProxy.hasRole(DEFAULT_ADMIN_ROLE, currentAdmin);
        console.log("Timelock has DEFAULT_ADMIN_ROLE after:", timelockHasRoleAfter);
        console.log("Current Admin has DEFAULT_ADMIN_ROLE after:", currentAdminHasRoleAfter);

        if (!timelockHasRoleAfter && currentAdminHasRoleAfter) {
            console.log("\nTEST PASSED: DEFAULT_ADMIN_ROLE transferred back successfully");
        } else {
            console.log("\nTEST FAILED: DEFAULT_ADMIN_ROLE transfer back incomplete");
        }
    }

    /**
     * @notice Test transferring ProxyAdmin ownership from Timelock back to currentAdmin
     */
    function testTransferProxyAdminOwnershipFromTimelock() internal {
        console.log("--- Step 1: Check current ProxyAdmin owner ---");
        address owner = proxyAdmin.owner();
        console.log("Current ProxyAdmin owner:", owner);

        if (owner != timelockAddress) {
            console.log("SKIPPED: Timelock is not the current owner");
            return;
        }

        if (owner == currentAdmin) {
            console.log("SKIPPED: Current Admin is already the owner");
            return;
        }

        console.log("\n--- Step 2: Prepare transfer ownership operation ---");

        // Prepare the call to transfer ownership
        bytes memory transferOwnershipCalldata = abi.encodeCall(Ownable.transferOwnership, (currentAdmin));

        bytes32 operationId = timelock.hashOperation(proxyAdminAddress, 0, transferOwnershipCalldata, PREDECESSOR, SALT);

        console.log("Transfer Ownership Operation ID:");
        console.logBytes32(operationId);

        bool isScheduled = timelock.isOperationPending(operationId);
        console.log("Operation already scheduled:", isScheduled);

        console.log("\n--- Step 3: Schedule transfer ownership operation ---");

        if (!isScheduled) {
            vm.startPrank(proposer);

            try timelock.schedule(proxyAdminAddress, 0, transferOwnershipCalldata, PREDECESSOR, SALT, minDelay) {
                console.log("SUCCESS: Transfer ownership operation scheduled");

                bool isPending = timelock.isOperationPending(operationId);
                console.log("Operation is pending:", isPending);

                uint256 timestamp = timelock.getTimestamp(operationId);
                console.log("Operation ready at timestamp:", timestamp);
            } catch Error(string memory reason) {
                console.log("FAILED to schedule transfer ownership: ", reason);
                vm.stopPrank();
                return;
            } catch (bytes memory lowLevelData) {
                console.log("FAILED to schedule transfer ownership with low-level error");
                console.logBytes(lowLevelData);
                vm.stopPrank();
                return;
            }

            vm.stopPrank();
        } else {
            console.log("Transfer ownership operation already scheduled, skipping schedule step");
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

        bool isReady = timelock.isOperationReady(operationId);
        console.log("Operation is ready:", isReady);

        console.log("\n--- Step 5: Execute transfer ownership operation ---");

        vm.startPrank(executor);

        try timelock.execute(proxyAdminAddress, 0, transferOwnershipCalldata, PREDECESSOR, SALT) {
            console.log("SUCCESS: Transfer ownership operation executed");
        } catch Error(string memory reason) {
            console.log("FAILED to execute transfer ownership: ", reason);
            vm.stopPrank();
            return;
        } catch (bytes memory lowLevelData) {
            console.log("FAILED to execute transfer ownership with low-level error");
            console.logBytes(lowLevelData);
            vm.stopPrank();
            return;
        }

        vm.stopPrank();

        console.log("\n--- Step 6: Verify result ---");

        address newOwner = proxyAdmin.owner();
        console.log("New ProxyAdmin owner:", newOwner);

        bool isDone = timelock.isOperationDone(operationId);
        console.log("Operation is done:", isDone);

        if (newOwner == currentAdmin && isDone) {
            console.log("\nTEST PASSED: ProxyAdmin ownership transferred back successfully");
        } else {
            console.log("\nTEST FAILED: ProxyAdmin ownership not transferred back");
        }
    }
}
