// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {TimelockController} from
    "@openzeppelin/contracts/governance/TimelockController.sol";
import {
    ProxyAdmin,
    ITransparentUpgradeableProxy
} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {Token} from "../contracts/Token.sol";
import {Proxy} from "../contracts/Proxy.sol";

/**
 * @title xBTCTimelockTest
 * @notice Comprehensive test suite for xBTC with TimelockController governance
 * @dev Tests timelock-based upgrades and role management
 */
contract xBTCTimelockTest is Test {
    // Contracts
    TimelockController public timelock;
    ProxyAdmin public proxyAdmin;
    Token public implementation;
    Token public implementationV2;
    Proxy public proxy;
    Token public xbtcToken;

    // Roles
    bytes32 public constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 public constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant DENY_LISTER_ROLE = keccak256("DENY_LISTER_ROLE");

    // Test accounts
    address public deployer;
    address public proposer;
    address public executor;
    address public minter;
    address public receiver;
    address public user1;
    address public user2;

    // Constants
    uint256 public constant MIN_DELAY = 3 days;
    uint256 public constant DECIMALS = 8;
    uint256 public constant MAX_SUPPLY = 21_000_000 * 10 ** DECIMALS;

    // Events
    event CallScheduled(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    );
    event CallExecuted(
        bytes32 indexed id,
        uint256 indexed index,
        address target,
        uint256 value,
        bytes data
    );
    event Upgraded(address indexed implementation);

    function setUp() public {
        // Setup accounts
        deployer = address(this);
        proposer = makeAddr("proposer");
        executor = makeAddr("executor");
        minter = makeAddr("minter");
        receiver = makeAddr("receiver");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy timelock with proper roles
        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);
        proposers[0] = proposer;
        executors[0] = executor;

        timelock = new TimelockController(
            MIN_DELAY,
            proposers,
            executors,
            address(0) // No admin is granted, so the TimelockController will be the DEFAULT_ADMIN_ROLE
        );

        // Deploy implementation
        implementation = new Token();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            Token.initialize.selector,
            "Cross-Chain Bitcoin",
            "xBTC",
            address(timelock), // denyLister (timelock has DEFAULT_ADMIN_ROLE)
            minter,
            receiver,
            MAX_SUPPLY
        );

        // Deploy proxy with timelock as initialOwner
        // TransparentUpgradeableProxy will create a ProxyAdmin automatically
        proxy = new Proxy(
            address(implementation),
            address(timelock), // initialOwner of the auto-created ProxyAdmin
            initData
        );

        // Get the auto-created ProxyAdmin address
        // The ProxyAdmin is stored in the proxy's admin slot
        bytes32 adminSlot =
            bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        address adminAddress =
            address(uint160(uint256(vm.load(address(proxy), adminSlot))));
        proxyAdmin = ProxyAdmin(adminAddress);

        // Get Token interface for proxy
        xbtcToken = Token(address(proxy));

        // Verify initial setup
        assertEq(xbtcToken.name(), "Cross-Chain Bitcoin");
        assertEq(xbtcToken.symbol(), "xBTC");
        assertTrue(
            xbtcToken.hasRole(xbtcToken.DEFAULT_ADMIN_ROLE(), address(timelock))
        );
        assertTrue(xbtcToken.hasRole(DENY_LISTER_ROLE, address(timelock)));
        assertTrue(xbtcToken.hasRole(MINTER_ROLE, minter));

        // Verify timelock roles
        assertTrue(timelock.hasRole(PROPOSER_ROLE, proposer));
        assertTrue(timelock.hasRole(CANCELLER_ROLE, proposer));
        assertTrue(timelock.hasRole(EXECUTOR_ROLE, executor));
    }

    /*//////////////////////////////////////////////////////////////
                        UPGRADE IMPLEMENTATION TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test upgrading implementation through timelock
     */
    function test_UpgradeImplementationThroughTimelock() public {
        console.log("\n=== Test: Upgrade Implementation Through Timelock ===");

        // Deploy new implementation (V2)
        implementationV2 = new Token();
        console.log(
            "New implementation deployed at:", address(implementationV2)
        );

        // Prepare upgrade call data
        bytes memory upgradeCallData = abi.encodeCall(
            ProxyAdmin.upgradeAndCall,
            (
                ITransparentUpgradeableProxy(address(proxy)),
                address(implementationV2),
                ""
            )
        );

        // Schedule the upgrade through timelock
        vm.startPrank(proposer);
        bytes32 operationId = timelock.hashOperation(
            address(proxyAdmin), 0, upgradeCallData, bytes32(0), bytes32(0)
        );

        console.log("Scheduling upgrade operation...");
        timelock.schedule(
            address(proxyAdmin),
            0,
            upgradeCallData,
            bytes32(0),
            bytes32(0),
            MIN_DELAY
        );
        vm.stopPrank();

        // Verify operation is pending
        assertTrue(timelock.isOperationPending(operationId));
        assertFalse(timelock.isOperationReady(operationId));
        console.log("Operation scheduled successfully");

        // Try to execute before delay - should fail
        vm.startPrank(executor);
        vm.expectRevert();
        timelock.execute(
            address(proxyAdmin), 0, upgradeCallData, bytes32(0), bytes32(0)
        );
        vm.stopPrank();
        console.log("Execution blocked before delay (as expected)");

        // Fast forward time past the delay
        vm.warp(block.timestamp + MIN_DELAY);
        console.log("Time advanced by", MIN_DELAY / 1 days, "days");

        // Verify operation is now ready
        assertTrue(timelock.isOperationReady(operationId));

        // Execute the upgrade
        vm.startPrank(executor);
        timelock.execute(
            address(proxyAdmin), 0, upgradeCallData, bytes32(0), bytes32(0)
        );
        vm.stopPrank();
        console.log("Upgrade executed successfully");

        // Verify operation is done
        assertTrue(timelock.isOperationDone(operationId));

        // Verify the contract still works after upgrade
        assertEq(xbtcToken.name(), "Cross-Chain Bitcoin");
        assertEq(xbtcToken.symbol(), "xBTC");
        assertTrue(
            xbtcToken.hasRole(xbtcToken.DEFAULT_ADMIN_ROLE(), address(timelock))
        );

        console.log("=== Upgrade Test Passed ===\n");
    }

    /**
     * @notice Test that non-proposer cannot schedule operations
     */
    function test_RevertWhen_NonProposerSchedulesUpgrade() public {
        console.log("\n=== Test: Non-Proposer Cannot Schedule ===");

        implementationV2 = new Token();

        bytes memory upgradeCallData = abi.encodeCall(
            ProxyAdmin.upgradeAndCall,
            (
                ITransparentUpgradeableProxy(address(proxy)),
                address(implementationV2),
                ""
            )
        );

        // Try to schedule as non-proposer
        vm.startPrank(user1);
        vm.expectRevert();
        timelock.schedule(
            address(proxyAdmin),
            0,
            upgradeCallData,
            bytes32(0),
            bytes32(0),
            MIN_DELAY
        );
        vm.stopPrank();

        console.log("Non-proposer correctly blocked from scheduling");
        console.log("=== Test Passed ===\n");
    }

    /**
     * @notice Test that non-executor cannot execute operations
     */
    function test_RevertWhen_NonExecutorExecutesOperation() public {
        console.log("\n=== Test: Non-Executor Cannot Execute ===");

        implementationV2 = new Token();

        bytes memory upgradeCallData = abi.encodeCall(
            ProxyAdmin.upgradeAndCall,
            (
                ITransparentUpgradeableProxy(address(proxy)),
                address(implementationV2),
                ""
            )
        );

        // Schedule operation
        vm.prank(proposer);
        timelock.schedule(
            address(proxyAdmin),
            0,
            upgradeCallData,
            bytes32(0),
            bytes32(0),
            MIN_DELAY
        );

        // Fast forward
        vm.warp(block.timestamp + MIN_DELAY);

        // Try to execute as non-executor
        vm.startPrank(user1);
        vm.expectRevert();
        timelock.execute(
            address(proxyAdmin), 0, upgradeCallData, bytes32(0), bytes32(0)
        );
        vm.stopPrank();

        console.log("Non-executor correctly blocked from executing");
        console.log("=== Test Passed ===\n");
    }

    /*//////////////////////////////////////////////////////////////
                        ROLE MANAGEMENT TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test granting minter role through timelock
     */
    function test_GrantMinterRoleThroughTimelock() public {
        console.log("\n=== Test: Grant Minter Role Through Timelock ===");

        address newMinter = makeAddr("newMinter");
        console.log("Granting MINTER_ROLE to:", newMinter);

        // Prepare grant role call data
        bytes memory grantRoleCallData = abi.encodeWithSelector(
            IAccessControl.grantRole.selector, MINTER_ROLE, newMinter
        );

        // Schedule the role grant
        vm.prank(proposer);
        timelock.schedule(
            address(xbtcToken),
            0,
            grantRoleCallData,
            bytes32(0),
            bytes32(uint256(1)), // unique salt
            MIN_DELAY
        );

        // Fast forward and execute
        vm.warp(block.timestamp + MIN_DELAY);
        vm.prank(executor);
        timelock.execute(
            address(xbtcToken),
            0,
            grantRoleCallData,
            bytes32(0),
            bytes32(uint256(1))
        );

        // Verify role granted
        assertTrue(xbtcToken.hasRole(MINTER_ROLE, newMinter));
        console.log("MINTER_ROLE granted successfully");

        // Verify new minter can mint
        vm.prank(newMinter);
        xbtcToken.mint(receiver, 1000 * 10 ** 8);
        assertEq(xbtcToken.balanceOf(receiver), 1000 * 10 ** 8);
        console.log("New minter can mint tokens");

        console.log("=== Test Passed ===\n");
    }

    /**
     * @notice Test revoking minter role through timelock
     */
    function test_RevokeMinterRoleThroughTimelock() public {
        console.log("\n=== Test: Revoke Minter Role Through Timelock ===");

        // Verify minter currently has role
        assertTrue(xbtcToken.hasRole(MINTER_ROLE, minter));

        // Prepare revoke role call data
        bytes memory revokeRoleCallData = abi.encodeWithSelector(
            IAccessControl.revokeRole.selector, MINTER_ROLE, minter
        );

        // Schedule the role revocation
        vm.prank(proposer);
        timelock.schedule(
            address(xbtcToken),
            0,
            revokeRoleCallData,
            bytes32(0),
            bytes32(uint256(2)), // unique salt
            MIN_DELAY
        );

        // Fast forward and execute
        vm.warp(block.timestamp + MIN_DELAY);
        vm.prank(executor);
        timelock.execute(
            address(xbtcToken),
            0,
            revokeRoleCallData,
            bytes32(0),
            bytes32(uint256(2))
        );

        // Verify role revoked
        assertFalse(xbtcToken.hasRole(MINTER_ROLE, minter));
        console.log("MINTER_ROLE revoked successfully");

        // Verify old minter cannot mint
        vm.startPrank(minter);
        vm.expectRevert();
        xbtcToken.mint(receiver, 1000 * 10 ** 8);
        vm.stopPrank();
        console.log("Revoked minter cannot mint (as expected)");

        console.log("=== Test Passed ===\n");
    }

    /*//////////////////////////////////////////////////////////////
                        PAUSE/UNPAUSE TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test pausing contract through timelock
     */
    function test_PauseContractThroughTimelock() public {
        console.log("\n=== Test: Pause Contract Through Timelock ===");

        // Mint some tokens first
        vm.prank(minter);
        xbtcToken.mint(receiver, 1000 * 10 ** 8);

        // Transfer some to user1
        vm.prank(receiver);
        require(xbtcToken.transfer(user1, 100 * 10 ** 8), "Transfer failed");

        // Prepare pause call data
        bytes memory pauseCallData =
            abi.encodeWithSelector(Token.pause.selector);

        // Schedule pause
        vm.prank(proposer);
        timelock.schedule(
            address(xbtcToken),
            0,
            pauseCallData,
            bytes32(0),
            bytes32(uint256(3)),
            MIN_DELAY
        );

        // Fast forward and execute
        vm.warp(block.timestamp + MIN_DELAY);
        vm.prank(executor);
        timelock.execute(
            address(xbtcToken),
            0,
            pauseCallData,
            bytes32(0),
            bytes32(uint256(3))
        );

        // Verify contract is paused
        assertTrue(xbtcToken.paused());
        console.log("Contract paused successfully");

        // Verify transfers are blocked
        vm.startPrank(user1);
        vm.expectRevert();
        xbtcToken.transfer(user2, 10 * 10 ** 8);
        vm.stopPrank();
        console.log("Transfers blocked during pause");

        console.log("=== Test Passed ===\n");
    }

    /**
     * @notice Test unpausing contract through timelock
     */
    function test_UnpauseContractThroughTimelock() public {
        console.log("\n=== Test: Unpause Contract Through Timelock ===");

        // First pause the contract (directly as timelock for speed)
        bytes memory pauseCallData =
            abi.encodeWithSelector(Token.pause.selector);
        vm.prank(proposer);
        timelock.schedule(
            address(xbtcToken),
            0,
            pauseCallData,
            bytes32(0),
            bytes32(uint256(4)),
            MIN_DELAY
        );
        vm.warp(block.timestamp + MIN_DELAY);
        vm.prank(executor);
        timelock.execute(
            address(xbtcToken),
            0,
            pauseCallData,
            bytes32(0),
            bytes32(uint256(4))
        );

        assertTrue(xbtcToken.paused());
        console.log("Contract paused");

        // Prepare unpause call data
        bytes memory unpauseCallData =
            abi.encodeWithSelector(Token.unpause.selector);

        // Schedule unpause
        vm.prank(proposer);
        timelock.schedule(
            address(xbtcToken),
            0,
            unpauseCallData,
            bytes32(0),
            bytes32(uint256(5)),
            MIN_DELAY
        );

        // Fast forward and execute
        vm.warp(block.timestamp + MIN_DELAY * 2);
        vm.prank(executor);
        timelock.execute(
            address(xbtcToken),
            0,
            unpauseCallData,
            bytes32(0),
            bytes32(uint256(5))
        );

        // Verify contract is unpaused
        assertFalse(xbtcToken.paused());
        console.log("Contract unpaused successfully");

        // Mint and verify transfers work
        vm.prank(minter);
        xbtcToken.mint(receiver, 1000 * 10 ** 8);

        vm.prank(receiver);
        require(xbtcToken.transfer(user1, 100 * 10 ** 8), "Transfer failed");
        assertEq(xbtcToken.balanceOf(user1), 100 * 10 ** 8);
        console.log("Transfers working after unpause");

        console.log("=== Test Passed ===\n");
    }

    /*//////////////////////////////////////////////////////////////
                        DENY LIST TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test adding address to deny list through timelock
     */
    function test_AddToDenyListThroughTimelock() public {
        console.log("\n=== Test: Add to Deny List Through Timelock ===");

        // Prepare add to deny list call data
        bytes memory addToDenyListCallData =
            abi.encodeWithSelector(Token.addToDenyList.selector, user1);

        // Schedule operation
        vm.prank(proposer);
        timelock.schedule(
            address(xbtcToken),
            0,
            addToDenyListCallData,
            bytes32(0),
            bytes32(uint256(6)),
            MIN_DELAY
        );

        // Fast forward and execute
        vm.warp(block.timestamp + MIN_DELAY);
        vm.prank(executor);
        timelock.execute(
            address(xbtcToken),
            0,
            addToDenyListCallData,
            bytes32(0),
            bytes32(uint256(6))
        );

        // Verify user1 is in deny list
        assertTrue(xbtcToken.denyList(user1));
        console.log("User added to deny list");

        // Mint tokens to receiver
        vm.prank(minter);
        xbtcToken.mint(receiver, 1000 * 10 ** 8);

        // Verify transfers to denied address fail
        vm.startPrank(receiver);
        vm.expectRevert();
        xbtcToken.transfer(user1, 100 * 10 ** 8);
        vm.stopPrank();
        console.log("Transfers to denied address blocked");

        console.log("=== Test Passed ===\n");
    }

    /*//////////////////////////////////////////////////////////////
                        BATCH OPERATIONS TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test executing batch operations through timelock
     */
    function test_BatchOperationsThroughTimelock() public {
        console.log("\n=== Test: Batch Operations Through Timelock ===");

        address newMinter1 = makeAddr("newMinter1");
        address newMinter2 = makeAddr("newMinter2");

        // Prepare batch operations
        address[] memory targets = new address[](2);
        uint256[] memory values = new uint256[](2);
        bytes[] memory calldatas = new bytes[](2);

        targets[0] = address(xbtcToken);
        targets[1] = address(xbtcToken);
        values[0] = 0;
        values[1] = 0;
        calldatas[0] = abi.encodeWithSelector(
            IAccessControl.grantRole.selector, MINTER_ROLE, newMinter1
        );
        calldatas[1] = abi.encodeWithSelector(
            IAccessControl.grantRole.selector, MINTER_ROLE, newMinter2
        );

        // Schedule batch
        vm.prank(proposer);
        timelock.scheduleBatch(
            targets,
            values,
            calldatas,
            bytes32(0),
            bytes32(uint256(7)),
            MIN_DELAY
        );

        // Fast forward and execute
        vm.warp(block.timestamp + MIN_DELAY);
        vm.prank(executor);
        timelock.executeBatch(
            targets, values, calldatas, bytes32(0), bytes32(uint256(7))
        );

        // Verify both roles granted
        assertTrue(xbtcToken.hasRole(MINTER_ROLE, newMinter1));
        assertTrue(xbtcToken.hasRole(MINTER_ROLE, newMinter2));
        console.log("Batch operations executed successfully");
        console.log("Both minters granted MINTER_ROLE");

        console.log("=== Test Passed ===\n");
    }

    /*//////////////////////////////////////////////////////////////
                        CANCELLATION TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test cancelling scheduled operation
     */
    function test_CancelScheduledOperation() public {
        console.log("\n=== Test: Cancel Scheduled Operation ===");

        implementationV2 = new Token();

        bytes memory upgradeCallData = abi.encodeCall(
            ProxyAdmin.upgradeAndCall,
            (
                ITransparentUpgradeableProxy(address(proxy)),
                address(implementationV2),
                ""
            )
        );

        // Calculate operation ID
        bytes32 operationId = timelock.hashOperation(
            address(proxyAdmin),
            0,
            upgradeCallData,
            bytes32(0),
            bytes32(uint256(8))
        );

        // Schedule operation
        vm.prank(proposer);
        timelock.schedule(
            address(proxyAdmin),
            0,
            upgradeCallData,
            bytes32(0),
            bytes32(uint256(8)),
            MIN_DELAY
        );

        assertTrue(timelock.isOperationPending(operationId));
        console.log("Operation scheduled");

        // Cancel operation (proposer has canceller role by default)
        vm.prank(proposer);
        timelock.cancel(operationId);

        assertFalse(timelock.isOperationPending(operationId));
        console.log("Operation cancelled successfully");

        // Verify cannot execute cancelled operation
        vm.warp(block.timestamp + MIN_DELAY);
        vm.startPrank(executor);
        vm.expectRevert();
        timelock.execute(
            address(proxyAdmin),
            0,
            upgradeCallData,
            bytes32(0),
            bytes32(uint256(8))
        );
        vm.stopPrank();
        console.log("Cancelled operation cannot be executed");

        console.log("=== Test Passed ===\n");
    }

    /*//////////////////////////////////////////////////////////////
                    TIMELOCK SELF-ADMINISTRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test granting new proposer role through timelock self-administration
     */
    function test_GrantProposerRoleThroughTimelock() public {
        console.log("\n=== Test: Grant Proposer Role Through Timelock ===");

        address newProposer = makeAddr("newProposer");
        console.log("Granting PROPOSER_ROLE to:", newProposer);

        // Verify newProposer doesn't have role yet
        assertFalse(timelock.hasRole(PROPOSER_ROLE, newProposer));

        // Prepare grant role call data (timelock grants role to itself)
        bytes memory grantRoleCallData = abi.encodeWithSelector(
            IAccessControl.grantRole.selector, PROPOSER_ROLE, newProposer
        );

        // Schedule the role grant through timelock
        vm.prank(proposer);
        timelock.schedule(
            address(timelock),
            0,
            grantRoleCallData,
            bytes32(0),
            bytes32(uint256(200)), // unique salt
            MIN_DELAY
        );
        console.log("Proposer role grant scheduled");

        // Fast forward and execute
        vm.warp(block.timestamp + MIN_DELAY);
        vm.prank(executor);
        timelock.execute(
            address(timelock),
            0,
            grantRoleCallData,
            bytes32(0),
            bytes32(uint256(200))
        );

        // Verify role granted
        assertTrue(timelock.hasRole(PROPOSER_ROLE, newProposer));
        console.log("PROPOSER_ROLE granted successfully");

        // Note: CANCELLER_ROLE is only auto-granted during constructor.
        // When granting PROPOSER_ROLE later, CANCELLER_ROLE must be granted separately if needed.
        assertFalse(timelock.hasRole(CANCELLER_ROLE, newProposer));
        console.log(
            "CANCELLER_ROLE NOT auto-granted (must be granted separately if needed)"
        );

        // Verify new proposer can schedule operations
        implementationV2 = new Token();
        bytes memory testCallData = abi.encodeCall(
            ProxyAdmin.upgradeAndCall,
            (
                ITransparentUpgradeableProxy(address(proxy)),
                address(implementationV2),
                ""
            )
        );

        vm.prank(newProposer);
        timelock.schedule(
            address(proxyAdmin),
            0,
            testCallData,
            bytes32(0),
            bytes32(uint256(201)),
            MIN_DELAY
        );
        console.log("New proposer can schedule operations");

        console.log("=== Test Passed ===\n");
    }

    /**
     * @notice Test granting new executor role through timelock self-administration
     */
    function test_GrantExecutorRoleThroughTimelock() public {
        console.log("\n=== Test: Grant Executor Role Through Timelock ===");

        address newExecutor = makeAddr("newExecutor");
        console.log("Granting EXECUTOR_ROLE to:", newExecutor);

        // Verify newExecutor doesn't have role yet
        assertFalse(timelock.hasRole(EXECUTOR_ROLE, newExecutor));

        // Prepare grant role call data
        bytes memory grantRoleCallData = abi.encodeWithSelector(
            IAccessControl.grantRole.selector, EXECUTOR_ROLE, newExecutor
        );

        // Schedule the role grant
        vm.prank(proposer);
        timelock.schedule(
            address(timelock),
            0,
            grantRoleCallData,
            bytes32(0),
            bytes32(uint256(202)),
            MIN_DELAY
        );
        console.log("Executor role grant scheduled");

        // Fast forward and execute
        vm.warp(block.timestamp + MIN_DELAY);
        vm.prank(executor);
        timelock.execute(
            address(timelock),
            0,
            grantRoleCallData,
            bytes32(0),
            bytes32(uint256(202))
        );

        // Verify role granted
        assertTrue(timelock.hasRole(EXECUTOR_ROLE, newExecutor));
        console.log("EXECUTOR_ROLE granted successfully");

        // Verify new executor can execute operations
        // First schedule an operation
        implementationV2 = new Token();
        bytes memory testCallData = abi.encodeCall(
            ProxyAdmin.upgradeAndCall,
            (
                ITransparentUpgradeableProxy(address(proxy)),
                address(implementationV2),
                ""
            )
        );

        vm.prank(proposer);
        timelock.schedule(
            address(proxyAdmin),
            0,
            testCallData,
            bytes32(0),
            bytes32(uint256(203)),
            MIN_DELAY
        );

        // Wait for delay
        vm.warp(block.timestamp + MIN_DELAY * 2);

        // New executor can execute
        vm.prank(newExecutor);
        timelock.execute(
            address(proxyAdmin),
            0,
            testCallData,
            bytes32(0),
            bytes32(uint256(203))
        );
        console.log("New executor can execute operations");

        console.log("=== Test Passed ===\n");
    }

    /**
     * @notice Test revoking proposer role through timelock self-administration
     */
    function test_RevokeProposerRoleThroughTimelock() public {
        console.log("\n=== Test: Revoke Proposer Role Through Timelock ===");

        // Verify proposer currently has role
        assertTrue(timelock.hasRole(PROPOSER_ROLE, proposer));

        // Prepare revoke role call data
        bytes memory revokeRoleCallData = abi.encodeWithSelector(
            IAccessControl.revokeRole.selector, PROPOSER_ROLE, proposer
        );

        // Schedule the role revocation
        vm.prank(proposer);
        timelock.schedule(
            address(timelock),
            0,
            revokeRoleCallData,
            bytes32(0),
            bytes32(uint256(204)),
            MIN_DELAY
        );
        console.log("Proposer role revocation scheduled");

        // Fast forward and execute
        vm.warp(block.timestamp + MIN_DELAY);
        vm.prank(executor);
        timelock.execute(
            address(timelock),
            0,
            revokeRoleCallData,
            bytes32(0),
            bytes32(uint256(204))
        );

        // Verify role revoked
        assertFalse(timelock.hasRole(PROPOSER_ROLE, proposer));
        console.log("PROPOSER_ROLE revoked successfully");

        // Verify revoked proposer cannot schedule
        vm.startPrank(proposer);
        vm.expectRevert();
        timelock.schedule(
            address(xbtcToken),
            0,
            abi.encodeWithSelector(Token.pause.selector),
            bytes32(0),
            bytes32(uint256(205)),
            MIN_DELAY
        );
        vm.stopPrank();
        console.log("Revoked proposer cannot schedule operations");

        console.log("=== Test Passed ===\n");
    }

    /**
     * @notice Test changing minimum delay through timelock self-administration
     */
    function test_UpdateMinDelayThroughTimelock() public {
        console.log("\n=== Test: Update Minimum Delay Through Timelock ===");

        uint256 oldDelay = timelock.getMinDelay();
        uint256 newDelay = 7 days;
        console.log("Current min delay:", oldDelay / 1 days, "days");
        console.log("New min delay:", newDelay / 1 days, "days");

        // Prepare update delay call data
        bytes memory updateDelayCallData =
            abi.encodeWithSelector(timelock.updateDelay.selector, newDelay);

        // Schedule the delay update
        vm.prank(proposer);
        timelock.schedule(
            address(timelock),
            0,
            updateDelayCallData,
            bytes32(0),
            bytes32(uint256(206)),
            MIN_DELAY
        );
        console.log("Min delay update scheduled");

        // Fast forward and execute
        vm.warp(block.timestamp + MIN_DELAY);
        vm.prank(executor);
        timelock.execute(
            address(timelock),
            0,
            updateDelayCallData,
            bytes32(0),
            bytes32(uint256(206))
        );

        // Verify delay updated
        assertEq(timelock.getMinDelay(), newDelay);
        console.log(
            "Min delay updated successfully to", newDelay / 1 days, "days"
        );

        // Verify new operations require the new delay
        bytes memory testCallData = abi.encodeWithSelector(Token.pause.selector);

        vm.prank(proposer);
        timelock.schedule(
            address(xbtcToken),
            0,
            testCallData,
            bytes32(0),
            bytes32(uint256(207)),
            newDelay
        );

        bytes32 opId = timelock.hashOperation(
            address(xbtcToken),
            0,
            testCallData,
            bytes32(0),
            bytes32(uint256(207))
        );

        // Try to execute with old delay - should fail
        vm.warp(block.timestamp + MIN_DELAY);
        assertFalse(timelock.isOperationReady(opId));
        console.log("Operation not ready with old delay (as expected)");

        // Execute with new delay - should succeed
        vm.warp(block.timestamp + (newDelay - MIN_DELAY));
        assertTrue(timelock.isOperationReady(opId));
        vm.prank(executor);
        timelock.execute(
            address(xbtcToken),
            0,
            testCallData,
            bytes32(0),
            bytes32(uint256(207))
        );
        console.log("Operation executed with new delay");

        console.log("=== Test Passed ===\n");
    }

    /**
     * @notice Test batch self-administration: grant multiple roles at once
     */
    function test_BatchSelfAdministrationThroughTimelock() public {
        console.log(
            "\n=== Test: Batch Self-Administration Through Timelock ==="
        );

        address newProposer1 = makeAddr("newProposer1");
        address newProposer2 = makeAddr("newProposer2");
        address newExecutor1 = makeAddr("newExecutor1");

        console.log(
            "Granting roles to multiple addresses (including CANCELLER_ROLE)..."
        );

        // Prepare batch operations
        // Grant newProposer1 both PROPOSER_ROLE and CANCELLER_ROLE
        // Grant newProposer2 only PROPOSER_ROLE
        // Grant newExecutor1 EXECUTOR_ROLE
        address[] memory targets = new address[](4);
        uint256[] memory values = new uint256[](4);
        bytes[] memory calldatas = new bytes[](4);

        targets[0] = address(timelock);
        targets[1] = address(timelock);
        targets[2] = address(timelock);
        targets[3] = address(timelock);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;
        calldatas[0] = abi.encodeWithSelector(
            IAccessControl.grantRole.selector, PROPOSER_ROLE, newProposer1
        );
        calldatas[1] = abi.encodeWithSelector(
            IAccessControl.grantRole.selector, CANCELLER_ROLE, newProposer1
        );
        calldatas[2] = abi.encodeWithSelector(
            IAccessControl.grantRole.selector, PROPOSER_ROLE, newProposer2
        );
        calldatas[3] = abi.encodeWithSelector(
            IAccessControl.grantRole.selector, EXECUTOR_ROLE, newExecutor1
        );

        // Schedule batch
        vm.prank(proposer);
        timelock.scheduleBatch(
            targets,
            values,
            calldatas,
            bytes32(0),
            bytes32(uint256(208)),
            MIN_DELAY
        );
        console.log("Batch self-administration scheduled");

        // Fast forward and execute
        vm.warp(block.timestamp + MIN_DELAY);
        vm.prank(executor);
        timelock.executeBatch(
            targets, values, calldatas, bytes32(0), bytes32(uint256(208))
        );

        // Verify all roles granted
        assertTrue(timelock.hasRole(PROPOSER_ROLE, newProposer1));
        assertTrue(timelock.hasRole(CANCELLER_ROLE, newProposer1));
        assertTrue(timelock.hasRole(PROPOSER_ROLE, newProposer2));
        assertFalse(timelock.hasRole(CANCELLER_ROLE, newProposer2));
        assertTrue(timelock.hasRole(EXECUTOR_ROLE, newExecutor1));
        console.log("All roles granted successfully in batch");
        console.log("- newProposer1 has PROPOSER_ROLE + CANCELLER_ROLE");
        console.log("- newProposer2 has PROPOSER_ROLE only");
        console.log("- newExecutor1 has EXECUTOR_ROLE");

        console.log("=== Test Passed ===\n");
    }

    /**
     * @notice Test that direct role management without timelock fails
     */
    function test_RevertWhen_DirectSelfAdministrationWithoutTimelock() public {
        console.log("\n=== Test: Direct Self-Administration Fails ===");

        address newProposer = makeAddr("directProposer");

        // Try to grant role directly as proposer (should fail)
        vm.startPrank(proposer);
        vm.expectRevert();
        timelock.grantRole(PROPOSER_ROLE, newProposer);
        vm.stopPrank();
        console.log("Direct grantRole by proposer blocked (as expected)");

        // Try to grant role directly as executor (should fail)
        vm.startPrank(executor);
        vm.expectRevert();
        timelock.grantRole(PROPOSER_ROLE, newProposer);
        vm.stopPrank();
        console.log("Direct grantRole by executor blocked (as expected)");

        // Verify role not granted
        assertFalse(timelock.hasRole(PROPOSER_ROLE, newProposer));
        console.log("Role not granted without timelock governance");

        console.log("=== Test Passed ===\n");
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Full integration test: Upgrade and manage roles
     */
    function test_FullIntegrationScenario() public {
        console.log("\n=== Full Integration Test ===");
        console.log("Scenario: Upgrade implementation and transfer minter role");

        // Step 1: Deploy new implementation
        console.log("\nStep 1: Deploy new implementation");
        implementationV2 = new Token();
        console.log("New implementation:", address(implementationV2));

        // Step 2: Schedule upgrade
        console.log("\nStep 2: Schedule upgrade");
        bytes memory upgradeCallData = abi.encodeCall(
            ProxyAdmin.upgradeAndCall,
            (
                ITransparentUpgradeableProxy(address(proxy)),
                address(implementationV2),
                ""
            )
        );

        bytes32 upgradeOpId = timelock.hashOperation(
            address(proxyAdmin),
            0,
            upgradeCallData,
            bytes32(0),
            bytes32(uint256(100))
        );

        vm.prank(proposer);
        timelock.schedule(
            address(proxyAdmin),
            0,
            upgradeCallData,
            bytes32(0),
            bytes32(uint256(100)),
            MIN_DELAY
        );
        console.log("Upgrade scheduled");

        // Step 3: Schedule new minter role grant
        console.log("\nStep 3: Schedule new minter grant");
        address newMinter = makeAddr("newMinter");
        bytes memory grantRoleCallData = abi.encodeWithSelector(
            IAccessControl.grantRole.selector, MINTER_ROLE, newMinter
        );

        vm.prank(proposer);
        timelock.schedule(
            address(xbtcToken),
            0,
            grantRoleCallData,
            bytes32(0),
            bytes32(uint256(101)),
            MIN_DELAY
        );
        console.log("Role grant scheduled");

        // Step 4: Wait for timelock
        console.log("\nStep 4: Waiting for timelock delay...");
        vm.warp(block.timestamp + MIN_DELAY);
        console.log("Timelock delay passed");

        // Step 5: Execute upgrade
        console.log("\nStep 5: Execute upgrade");
        vm.prank(executor);
        timelock.execute(
            address(proxyAdmin),
            0,
            upgradeCallData,
            bytes32(0),
            bytes32(uint256(100))
        );
        assertTrue(timelock.isOperationDone(upgradeOpId));
        console.log("Upgrade executed");

        // Step 6: Execute role grant
        console.log("\nStep 6: Execute role grant");
        vm.prank(executor);
        timelock.execute(
            address(xbtcToken),
            0,
            grantRoleCallData,
            bytes32(0),
            bytes32(uint256(101))
        );
        assertTrue(xbtcToken.hasRole(MINTER_ROLE, newMinter));
        console.log("Role granted");

        // Step 7: Verify everything works
        console.log("\nStep 7: Verify functionality");
        vm.prank(newMinter);
        xbtcToken.mint(receiver, 5000 * 10 ** 8);
        assertEq(xbtcToken.balanceOf(receiver), 5000 * 10 ** 8);
        console.log("New minter can mint tokens");

        vm.prank(receiver);
        require(xbtcToken.transfer(user1, 1000 * 10 ** 8), "Transfer failed");
        assertEq(xbtcToken.balanceOf(user1), 1000 * 10 ** 8);
        console.log("Transfers working correctly");

        console.log("\n=== Integration Test Passed ===\n");
    }
}
