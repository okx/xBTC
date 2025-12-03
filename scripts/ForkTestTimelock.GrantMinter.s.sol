// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/access/IAccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../contracts/Token.sol";

/**
 * @title ForkTestTimelock
 * @notice Fork test script to simulate timelock schedule and execute operations on xLayer mainnet
 * @dev This script demonstrates:
 *      1. Forking xLayer mainnet
 *      2. Scheduling a timelock operation (grant minter role)
 *      3. Fast-forwarding time past the timelock delay
 *      4. Executing the scheduled operation
 *      5. Verifying the result
 *
 * Usage:
 *   forge script scripts/ForkTestTimelock.s.sol:ForkTestTimelock \
 *     --fork-url $XLAYER_RPC_URL \
 *     -vvvv
 */
contract ForkTestTimelockGrantMinterRole is Script {
    // ==================== Configuration ====================

    // Deployed contract addresses on xLayer mainnet
    // These should be set via environment variables or updated here
    address public timelockAddress;
    address public xbtcProxyAddress;

    // Test addresses
    address public proposer;
    address public executor;
    address public newMinter;

    // Role constants
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    // Timelock operation parameters
    bytes32 public constant SALT = bytes32(0);
    bytes32 public constant PREDECESSOR = bytes32(0);

    // Contract instances
    TimelockController public timelock;
    Token public xbtcProxy;

    // Operation tracking
    bytes32 public operationId;
    uint256 public minDelay;

    function setUp() public {
        // Load addresses from environment variables
        timelockAddress = vm.envAddress("TIMELOCK_ADDRESS");
        xbtcProxyAddress = vm.envAddress("XBTC_PROXY_ADDRESS");

        // Initialize contract instances
        timelock = TimelockController(payable(timelockAddress));
        xbtcProxy = Token(xbtcProxyAddress);

        proposer = vm.envAddress("PRIVILEGED_ADDRESS");
        executor = proposer;

        newMinter = vm.envAddress("NEW_MINTER_ADDRESS");

        console.log("=== Fork Test Configuration ===");
        console.log("Timelock Address:", timelockAddress);
        console.log("xBTC Proxy Address:", xbtcProxyAddress);
        console.log("New Minter:", newMinter);
        console.log("");
    }

    function run() external {
        // Query current state
        queryCurrentState();

        console.log("\n=== Test Scenario: Grant Minter Role via Timelock ===\n");
        testGrantMinterRole();

        console.log("\n=== Fork Test Completed Successfully ===\n");
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
        console.log("Is Proposer:", isProposer);

        // Check if executor has EXECUTOR_ROLE
        bool isExecutor = timelock.hasRole(EXECUTOR_ROLE, executor);
        console.log("Is Executor:", isExecutor);

        // Check current minter role status
        bool newMinterHasRole = xbtcProxy.hasRole(MINTER_ROLE, newMinter);
        console.log("New Minter has MINTER_ROLE:", newMinterHasRole);

        // Check if contract is paused
        bool isPaused = xbtcProxy.paused();
        console.log("xBTC Contract Paused:", isPaused);

        console.log("");

        // ========== Verify Timelock is both ProxyAdmin owner and DEFAULT_ADMIN_ROLE ==========
        console.log("=== Timelock Admin Role Verification ===");

        // 1. Get ProxyAdmin address from ERC1967 storage slot
        bytes32 ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        bytes32 proxyAdminSlot = vm.load(xbtcProxyAddress, ADMIN_SLOT);
        address proxyAdminAddress = address(uint160(uint256(proxyAdminSlot)));
        console.log("ProxyAdmin Contract Address:", proxyAdminAddress);

        // 2. Check Timelock is the owner of ProxyAdmin
        address proxyAdminOwner = Ownable(proxyAdminAddress).owner();
        console.log("ProxyAdmin Owner:", proxyAdminOwner);
        bool timelockIsProxyAdminOwner = (proxyAdminOwner == timelockAddress);
        console.log("Timelock is ProxyAdmin Owner:", timelockIsProxyAdminOwner);
        require(timelockIsProxyAdminOwner, "FAILED: Timelock is not ProxyAdmin owner");

        // 3. Check Timelock has DEFAULT_ADMIN_ROLE in Token
        bool timelockHasAdminRole = xbtcProxy.hasRole(DEFAULT_ADMIN_ROLE, timelockAddress);
        console.log("Timelock has DEFAULT_ADMIN_ROLE:", timelockHasAdminRole);
        require(timelockHasAdminRole, "FAILED: Timelock does not have DEFAULT_ADMIN_ROLE");

        console.log("");
        console.log("=== Why This Works (Timelock is both ProxyAdmin owner AND DEFAULT_ADMIN) ===");
        console.log("In OZ v5 TransparentUpgradeableProxy:");
        console.log("  1. ProxyAdmin CONTRACT is created automatically, Timelock is its OWNER");
        console.log("  2. Proxy only intercepts calls FROM ProxyAdmin CONTRACT (not owner)");
        console.log("  3. When Timelock calls proxy, msg.sender = Timelock != ProxyAdmin");
        console.log("  4. So the call is delegated normally to Token implementation");
        console.log("  5. Since Timelock has DEFAULT_ADMIN_ROLE, grantRole succeeds");
        console.log("");
        console.log("Key Insight: Timelock address != ProxyAdmin address");
        console.log("  Timelock:", timelockAddress);
        console.log("  ProxyAdmin:", proxyAdminAddress);
        console.log("  These are DIFFERENT addresses, so no interception occurs!");
        console.log("");
    }

    /**
     * @notice Test granting minter role through timelock
     */
    function testGrantMinterRole() internal {
        console.log("--- Step 1: Check if new minter already has role ---");
        bool hasRoleBefore = xbtcProxy.hasRole(MINTER_ROLE, newMinter);
        console.log("New minter has MINTER_ROLE before:", hasRoleBefore);

        if (hasRoleBefore) {
            console.log("SKIPPED: New minter already has MINTER_ROLE");
            return;
        }

        console.log("\n--- Step 2: Prepare operation calldata ---");

        // Prepare the inner call: grantRole(MINTER_ROLE, newMinter)
        bytes memory grantRoleCalldata =
            abi.encodeWithSelector(IAccessControl.grantRole.selector, MINTER_ROLE, newMinter);

        console.log("Inner calldata (grantRole):");
        console.logBytes(grantRoleCalldata);

        // Calculate operation ID
        operationId = timelock.hashOperation(
            xbtcProxyAddress, // target
            0, // value
            grantRoleCalldata, // data
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
            console.log("  target:", xbtcProxyAddress);
            console.log("  value: 0");
            console.log("  data:");
            console.logBytes(grantRoleCalldata);
            console.log("  predecessor:");
            console.logBytes32(PREDECESSOR);
            console.log("  salt:");
            console.logBytes32(SALT);
            console.log("  delay:", minDelay);

            try timelock.schedule(xbtcProxyAddress, 0, grantRoleCalldata, PREDECESSOR, SALT, minDelay) {
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

        try timelock.execute(xbtcProxyAddress, 0, grantRoleCalldata, PREDECESSOR, SALT) {
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

        // Check if new minter now has the role
        bool hasRoleAfter = xbtcProxy.hasRole(MINTER_ROLE, newMinter);
        console.log("New minter has MINTER_ROLE after:", hasRoleAfter);

        // Verify operation is done
        bool isDone = timelock.isOperationDone(operationId);
        console.log("Operation is done:", isDone);

        if (hasRoleAfter && isDone) {
            console.log("\nTEST PASSED: Minter role granted successfully via timelock");
        } else {
            console.log("\nTEST FAILED: Minter role not granted or operation not marked as done");
        }
    }
}
