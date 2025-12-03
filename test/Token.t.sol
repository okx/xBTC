// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Token} from "../contracts/Token.sol";
import {Proxy} from "../contracts/Proxy.sol";

/**
 * @title TokenTest
 * @notice Comprehensive tests for Token.sol and all derived token contracts
 */
contract TokenTest is Test {
    Token public token;
    Proxy public proxy;

    address public admin; // Same address for proxy admin owner and DEFAULT_ADMIN_ROLE
    address public denyLister;
    address public minter;
    address public receiver;
    address public user1;
    address public user2;

    uint256 public constant DECIMALS = 18;
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10 ** DECIMALS;

    // Events
    event AddedToDenyList(address indexed account);
    event RemovedFromDenyList(address indexed account);
    event MinterTransferred(
        address indexed previousMinter, address indexed newMinter
    );
    event DenyListerTransferred(
        address indexed previousDenyLister, address indexed newDenyLister
    );
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);
    event ReceiverSet(
        address indexed previousReceiver, address indexed newReceiver
    );

    function setUp() public {
        admin = makeAddr("admin");
        denyLister = makeAddr("denyLister");
        minter = makeAddr("minter");
        receiver = makeAddr("receiver");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        // Deploy Token implementation
        Token implementation = new Token();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            Token.initialize.selector,
            "Test Token",
            "TEST",
            admin,
            denyLister,
            minter,
            receiver,
            MAX_SUPPLY
        );

        // Deploy proxy with admin as both proxy admin owner and DEFAULT_ADMIN_ROLE holder
        // Note: In OZ v5 TransparentUpgradeableProxy, a ProxyAdmin CONTRACT is created
        // and admin becomes its OWNER. Calls from admin go through normally because
        // admin address != ProxyAdmin contract address.
        proxy = new Proxy(address(implementation), admin, initData);
        token = Token(address(proxy));
    }

    // ============ Initialize Tests ============

    function test_Initialize_Success() public view {
        assertEq(token.name(), "Test Token");
        assertEq(token.symbol(), "TEST");
        assertEq(token.MAX_SUPPLY(), MAX_SUPPLY);
        assertEq(token.authorizedReceiver(), receiver);
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(token.hasRole(token.DENY_LISTER_ROLE(), denyLister));
        assertTrue(token.hasRole(token.MINTER_ROLE(), minter));
    }

    function test_Initialize_RevertWhen_ZeroAddressReceiver() public {
        Token implementation = new Token();
        bytes memory initData = abi.encodeWithSelector(
            Token.initialize.selector,
            "Test Token",
            "TEST",
            admin,
            denyLister,
            minter,
            address(0), // zero address receiver
            MAX_SUPPLY
        );

        vm.expectRevert(Token.ZeroAddress.selector);
        new Proxy(address(implementation), admin, initData);
    }

    function test_Initialize_RevertWhen_ZeroMaxSupply() public {
        Token implementation = new Token();
        bytes memory initData = abi.encodeWithSelector(
            Token.initialize.selector,
            "Test Token",
            "TEST",
            admin,
            denyLister,
            minter,
            receiver,
            0 // zero max supply
        );

        vm.expectRevert(Token.ZeroAmount.selector);
        new Proxy(address(implementation), admin, initData);
    }

    // ============ setReceiver Tests ============

    function test_SetReceiver_Success() public {
        address newReceiver = makeAddr("newReceiver");

        vm.expectEmit(true, true, false, true);
        emit ReceiverSet(receiver, newReceiver);

        vm.prank(denyLister);
        token.setReceiver(newReceiver);

        assertEq(token.authorizedReceiver(), newReceiver);
    }

    function test_SetReceiver_RevertWhen_ZeroAddress() public {
        vm.prank(denyLister);
        vm.expectRevert(Token.ZeroAddress.selector);
        token.setReceiver(address(0));
    }

    function test_SetReceiver_RevertWhen_NotDenyLister() public {
        vm.prank(user1);
        vm.expectRevert();
        token.setReceiver(user1);
    }

    // ============ Mint Tests ============

    function test_Mint_Success() public {
        uint256 amount = 1000 * 10 ** DECIMALS;

        vm.expectEmit(true, false, false, true);
        emit Mint(receiver, amount);

        vm.prank(minter);
        token.mint(receiver, amount);

        assertEq(token.balanceOf(receiver), amount);
        assertEq(token.totalSupply(), amount);
    }

    function test_Mint_RevertWhen_ZeroAmount() public {
        vm.prank(minter);
        vm.expectRevert(Token.ZeroAmount.selector);
        token.mint(receiver, 0);
    }

    function test_Mint_RevertWhen_WrongReceiver() public {
        vm.prank(minter);
        vm.expectRevert(Token.NoAuthorizedReceiver.selector);
        token.mint(user1, 1000);
    }

    function test_Mint_RevertWhen_ExceedsMaxSupply() public {
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(
                Token.ExceedsMaxSupply.selector, MAX_SUPPLY + 1, MAX_SUPPLY
            )
        );
        token.mint(receiver, MAX_SUPPLY + 1);
    }

    function test_Mint_RevertWhen_Paused() public {
        vm.prank(denyLister);
        token.pause();

        vm.prank(minter);
        vm.expectRevert();
        token.mint(receiver, 1000);
    }

    function test_Mint_RevertWhen_NotMinter() public {
        vm.prank(user1);
        vm.expectRevert();
        token.mint(receiver, 1000);
    }

    // ============ Burn Tests ============

    function test_Burn_Success() public {
        uint256 mintAmount = 1000 * 10 ** DECIMALS;
        uint256 burnAmount = 500 * 10 ** DECIMALS;

        // First mint tokens to receiver
        vm.prank(minter);
        token.mint(receiver, mintAmount);

        // Transfer tokens from receiver to minter so minter can burn
        vm.prank(receiver);
        token.transfer(minter, mintAmount);

        vm.expectEmit(true, false, false, true);
        emit Burn(minter, burnAmount);

        vm.prank(minter);
        token.burn(burnAmount);

        assertEq(token.balanceOf(minter), mintAmount - burnAmount);
    }

    function test_Burn_RevertWhen_ZeroAmount() public {
        vm.prank(minter);
        vm.expectRevert(Token.ZeroAmount.selector);
        token.burn(0);
    }

    function test_Burn_RevertWhen_InsufficientBalance() public {
        vm.prank(minter);
        vm.expectRevert(
            abi.encodeWithSelector(Token.InsufficientBalance.selector, 0, 1000)
        );
        token.burn(1000);
    }

    function test_Burn_RevertWhen_Paused() public {
        // First mint and transfer tokens
        vm.prank(minter);
        token.mint(receiver, 1000);
        vm.prank(receiver);
        token.transfer(minter, 1000);

        vm.prank(denyLister);
        token.pause();

        vm.prank(minter);
        vm.expectRevert();
        token.burn(500);
    }

    function test_Burn_RevertWhen_NotMinter() public {
        vm.prank(user1);
        vm.expectRevert();
        token.burn(100);
    }

    // ============ Pause/Unpause Tests ============

    function test_Pause_Success() public {
        vm.prank(denyLister);
        token.pause();

        assertTrue(token.paused());
    }

    function test_Unpause_Success() public {
        vm.prank(denyLister);
        token.pause();

        vm.prank(denyLister);
        token.unpause();

        assertFalse(token.paused());
    }

    function test_Pause_RevertWhen_NotDenyLister() public {
        vm.prank(user1);
        vm.expectRevert();
        token.pause();
    }

    function test_Unpause_RevertWhen_NotDenyLister() public {
        vm.prank(denyLister);
        token.pause();

        vm.prank(user1);
        vm.expectRevert();
        token.unpause();
    }

    // ============ DenyList Tests ============

    function test_AddToDenyList_Success() public {
        vm.expectEmit(true, false, false, false);
        emit AddedToDenyList(user1);

        vm.prank(denyLister);
        token.addToDenyList(user1);

        assertTrue(token.denyList(user1));
    }

    function test_AddToDenyList_RevertWhen_ZeroAddress() public {
        vm.prank(denyLister);
        vm.expectRevert(Token.ZeroAddress.selector);
        token.addToDenyList(address(0));
    }

    function test_AddToDenyList_RevertWhen_NotDenyLister() public {
        vm.prank(user1);
        vm.expectRevert();
        token.addToDenyList(user2);
    }

    function test_RemoveFromDenyList_Success() public {
        vm.prank(denyLister);
        token.addToDenyList(user1);

        vm.expectEmit(true, false, false, false);
        emit RemovedFromDenyList(user1);

        vm.prank(denyLister);
        token.removeFromDenyList(user1);

        assertFalse(token.denyList(user1));
    }

    function test_RemoveFromDenyList_RevertWhen_NotDenyLister() public {
        vm.prank(user1);
        vm.expectRevert();
        token.removeFromDenyList(user2);
    }

    // ============ Batch DenyList Tests ============

    function test_BatchAddToDenyList_Success() public {
        address[] memory accounts = new address[](3);
        accounts[0] = user1;
        accounts[1] = user2;
        accounts[2] = makeAddr("user3");

        vm.prank(denyLister);
        token.batchAddToDenyList(accounts);

        assertTrue(token.denyList(user1));
        assertTrue(token.denyList(user2));
        assertTrue(token.denyList(accounts[2]));
    }

    function test_BatchAddToDenyList_SkipsAlreadyDenied() public {
        // First add user1
        vm.prank(denyLister);
        token.addToDenyList(user1);

        // Batch add including already denied user1
        address[] memory accounts = new address[](2);
        accounts[0] = user1;
        accounts[1] = user2;

        vm.prank(denyLister);
        token.batchAddToDenyList(accounts);

        assertTrue(token.denyList(user1));
        assertTrue(token.denyList(user2));
    }

    function test_BatchAddToDenyList_RevertWhen_EmptyArray() public {
        address[] memory accounts = new address[](0);

        vm.prank(denyLister);
        vm.expectRevert(Token.EmptyArray.selector);
        token.batchAddToDenyList(accounts);
    }

    function test_BatchAddToDenyList_RevertWhen_ZeroAddressInBatch() public {
        address[] memory accounts = new address[](2);
        accounts[0] = user1;
        accounts[1] = address(0);

        vm.prank(denyLister);
        vm.expectRevert(Token.ZeroAddress.selector);
        token.batchAddToDenyList(accounts);
    }

    function test_BatchAddToDenyList_RevertWhen_NotDenyLister() public {
        address[] memory accounts = new address[](1);
        accounts[0] = user1;

        vm.prank(user1);
        vm.expectRevert();
        token.batchAddToDenyList(accounts);
    }

    function test_BatchRemoveFromDenyList_Success() public {
        // First add to deny list
        address[] memory accounts = new address[](2);
        accounts[0] = user1;
        accounts[1] = user2;

        vm.prank(denyLister);
        token.batchAddToDenyList(accounts);

        // Now remove
        vm.prank(denyLister);
        token.batchRemoveFromDenyList(accounts);

        assertFalse(token.denyList(user1));
        assertFalse(token.denyList(user2));
    }

    function test_BatchRemoveFromDenyList_SkipsNotDenied() public {
        // Only add user1
        vm.prank(denyLister);
        token.addToDenyList(user1);

        // Batch remove including user2 who is not denied
        address[] memory accounts = new address[](2);
        accounts[0] = user1;
        accounts[1] = user2;

        vm.prank(denyLister);
        token.batchRemoveFromDenyList(accounts);

        assertFalse(token.denyList(user1));
        assertFalse(token.denyList(user2));
    }

    function test_BatchRemoveFromDenyList_RevertWhen_EmptyArray() public {
        address[] memory accounts = new address[](0);

        vm.prank(denyLister);
        vm.expectRevert(Token.EmptyArray.selector);
        token.batchRemoveFromDenyList(accounts);
    }

    function test_BatchRemoveFromDenyList_RevertWhen_NotDenyLister() public {
        address[] memory accounts = new address[](1);
        accounts[0] = user1;

        vm.prank(user1);
        vm.expectRevert();
        token.batchRemoveFromDenyList(accounts);
    }

    // ============ Admin Grant/Revoke Role Tests ============

    function test_AdminGrantMinterRole_Success() public {
        address newMinter = makeAddr("newMinter");
        bytes32 minterRole = token.MINTER_ROLE();

        vm.prank(admin);
        token.grantRole(minterRole, newMinter);

        assertTrue(token.hasRole(minterRole, newMinter));
        // Original minter still has role
        assertTrue(token.hasRole(minterRole, minter));
    }

    function test_AdminGrantDenyListerRole_Success() public {
        address newDenyLister = makeAddr("newDenyLister");
        bytes32 denyListerRole = token.DENY_LISTER_ROLE();

        vm.prank(admin);
        token.grantRole(denyListerRole, newDenyLister);

        assertTrue(token.hasRole(denyListerRole, newDenyLister));
        // Original deny lister still has role
        assertTrue(token.hasRole(denyListerRole, denyLister));
    }

    function test_AdminGrantAdminRole_Success() public {
        address newAdmin = makeAddr("newAdmin");
        bytes32 adminRole = token.DEFAULT_ADMIN_ROLE();

        vm.prank(admin);
        token.grantRole(adminRole, newAdmin);

        assertTrue(token.hasRole(adminRole, newAdmin));
        // Original admin still has role
        assertTrue(token.hasRole(adminRole, admin));
    }

    function test_AdminRevokeMinterRole_Success() public {
        bytes32 minterRole = token.MINTER_ROLE();

        vm.prank(admin);
        token.revokeRole(minterRole, minter);

        assertFalse(token.hasRole(minterRole, minter));
    }

    function test_AdminRevokeDenyListerRole_Success() public {
        bytes32 denyListerRole = token.DENY_LISTER_ROLE();

        vm.prank(admin);
        token.revokeRole(denyListerRole, denyLister);

        assertFalse(token.hasRole(denyListerRole, denyLister));
    }

    function test_AdminRevokeAdminRole_Success() public {
        // First grant admin to another address
        address newAdmin = makeAddr("newAdmin");
        bytes32 adminRole = token.DEFAULT_ADMIN_ROLE();

        vm.prank(admin);
        token.grantRole(adminRole, newAdmin);

        // Revoke original admin
        vm.prank(newAdmin);
        token.revokeRole(adminRole, admin);

        assertFalse(token.hasRole(adminRole, admin));
        assertTrue(token.hasRole(adminRole, newAdmin));
    }

    function test_GrantRole_RevertWhen_NotAdmin() public {
        address newMinter = makeAddr("newMinter");
        bytes32 minterRole = token.MINTER_ROLE();

        vm.prank(user1);
        vm.expectRevert();
        token.grantRole(minterRole, newMinter);
    }

    function test_RevokeRole_RevertWhen_NotAdmin() public {
        bytes32 minterRole = token.MINTER_ROLE();

        vm.prank(user1);
        vm.expectRevert();
        token.revokeRole(minterRole, minter);
    }

    function test_MinterCannotGrantMinterRole() public {
        address newMinter = makeAddr("newMinter");
        bytes32 minterRole = token.MINTER_ROLE();

        vm.prank(minter);
        vm.expectRevert();
        token.grantRole(minterRole, newMinter);
    }

    function test_DenyListerCannotGrantDenyListerRole() public {
        address newDenyLister = makeAddr("newDenyLister");
        bytes32 denyListerRole = token.DENY_LISTER_ROLE();

        vm.prank(denyLister);
        vm.expectRevert();
        token.grantRole(denyListerRole, newDenyLister);
    }

    function test_RevokedMinterCannotMint() public {
        bytes32 minterRole = token.MINTER_ROLE();

        // Admin revokes minter role
        vm.prank(admin);
        token.revokeRole(minterRole, minter);

        // Minter tries to mint
        vm.prank(minter);
        vm.expectRevert();
        token.mint(receiver, 1000);
    }

    function test_RevokedDenyListerCannotPause() public {
        bytes32 denyListerRole = token.DENY_LISTER_ROLE();

        // Admin revokes deny lister role
        vm.prank(admin);
        token.revokeRole(denyListerRole, denyLister);

        // Deny lister tries to pause
        vm.prank(denyLister);
        vm.expectRevert();
        token.pause();
    }

    function test_NewlyGrantedMinterCanMint() public {
        address newMinter = makeAddr("newMinter");
        bytes32 minterRole = token.MINTER_ROLE();

        // Admin grants minter role
        vm.prank(admin);
        token.grantRole(minterRole, newMinter);

        // New minter can mint
        vm.prank(newMinter);
        token.mint(receiver, 1000);

        assertEq(token.balanceOf(receiver), 1000);
    }

    function test_NewlyGrantedDenyListerCanPause() public {
        address newDenyLister = makeAddr("newDenyLister");
        bytes32 denyListerRole = token.DENY_LISTER_ROLE();

        // Admin grants deny lister role
        vm.prank(admin);
        token.grantRole(denyListerRole, newDenyLister);

        // New deny lister can pause
        vm.prank(newDenyLister);
        token.pause();

        assertTrue(token.paused());
    }

    function test_RenounceRole_Success() public {
        bytes32 minterRole = token.MINTER_ROLE();

        // Minter renounces their own role
        vm.prank(minter);
        token.renounceRole(minterRole, minter);

        assertFalse(token.hasRole(minterRole, minter));
    }

    function test_RenounceRole_RevertWhen_RenouncingOthersRole() public {
        bytes32 minterRole = token.MINTER_ROLE();

        // User1 tries to renounce minter's role
        vm.prank(user1);
        vm.expectRevert();
        token.renounceRole(minterRole, minter);
    }

    function test_MultipleRoleHolders() public {
        address minter2 = makeAddr("minter2");
        address minter3 = makeAddr("minter3");
        bytes32 minterRole = token.MINTER_ROLE();

        // Admin grants minter role to multiple addresses
        vm.startPrank(admin);
        token.grantRole(minterRole, minter2);
        token.grantRole(minterRole, minter3);
        vm.stopPrank();

        // All three can mint
        assertTrue(token.hasRole(minterRole, minter));
        assertTrue(token.hasRole(minterRole, minter2));
        assertTrue(token.hasRole(minterRole, minter3));

        // Revoke one, others still work
        vm.prank(admin);
        token.revokeRole(minterRole, minter2);

        assertFalse(token.hasRole(minterRole, minter2));
        assertTrue(token.hasRole(minterRole, minter));
        assertTrue(token.hasRole(minterRole, minter3));
    }

    // ============ Transfer Role Tests ============

    function test_TransferMinter_Success() public {
        address newMinter = makeAddr("newMinter");

        vm.expectEmit(true, true, false, false);
        emit MinterTransferred(minter, newMinter);

        vm.prank(minter);
        token.transferMinter(newMinter);

        assertTrue(token.hasRole(token.MINTER_ROLE(), newMinter));
        assertFalse(token.hasRole(token.MINTER_ROLE(), minter));
    }

    function test_TransferMinter_RevertWhen_ZeroAddress() public {
        vm.prank(minter);
        vm.expectRevert(Token.ZeroAddress.selector);
        token.transferMinter(address(0));
    }

    function test_TransferMinter_RevertWhen_SameAddress() public {
        vm.prank(minter);
        vm.expectRevert(Token.SameValue.selector);
        token.transferMinter(minter);
    }

    function test_TransferMinter_RevertWhen_NotMinter() public {
        vm.prank(user1);
        vm.expectRevert();
        token.transferMinter(user1);
    }

    function test_TransferDenyLister_Success() public {
        address newDenyLister = makeAddr("newDenyLister");

        vm.expectEmit(true, true, false, false);
        emit DenyListerTransferred(denyLister, newDenyLister);

        vm.prank(denyLister);
        token.transferDenyLister(newDenyLister);

        assertTrue(token.hasRole(token.DENY_LISTER_ROLE(), newDenyLister));
        assertFalse(token.hasRole(token.DENY_LISTER_ROLE(), denyLister));
    }

    function test_TransferDenyLister_RevertWhen_ZeroAddress() public {
        vm.prank(denyLister);
        vm.expectRevert(Token.ZeroAddress.selector);
        token.transferDenyLister(address(0));
    }

    function test_TransferDenyLister_RevertWhen_SameAddress() public {
        vm.prank(denyLister);
        vm.expectRevert(Token.SameValue.selector);
        token.transferDenyLister(denyLister);
    }

    function test_TransferDenyLister_RevertWhen_NotDenyLister() public {
        vm.prank(user1);
        vm.expectRevert();
        token.transferDenyLister(user1);
    }

    // ============ Transfer with DenyList Tests ============

    function test_Transfer_RevertWhen_SenderInDenyList() public {
        // Mint tokens
        vm.prank(minter);
        token.mint(receiver, 1000);

        // Add receiver to deny list
        vm.prank(denyLister);
        token.addToDenyList(receiver);

        // Try to transfer from denied address
        vm.prank(receiver);
        vm.expectRevert(
            abi.encodeWithSelector(Token.SenderInDenyList.selector, receiver)
        );
        token.transfer(user1, 100);
    }

    function test_Transfer_RevertWhen_RecipientInDenyList() public {
        // Mint tokens
        vm.prank(minter);
        token.mint(receiver, 1000);

        // Add user1 to deny list
        vm.prank(denyLister);
        token.addToDenyList(user1);

        // Try to transfer to denied address
        vm.prank(receiver);
        vm.expectRevert(
            abi.encodeWithSelector(Token.RecipientInDenyList.selector, user1)
        );
        token.transfer(user1, 100);
    }

    function test_TransferFrom_RevertWhen_SenderInDenyList() public {
        // Mint tokens
        vm.prank(minter);
        token.mint(receiver, 1000);

        // Approve user1
        vm.prank(receiver);
        token.approve(user1, 100);

        // Add receiver to deny list
        vm.prank(denyLister);
        token.addToDenyList(receiver);

        // Try to transfer from denied address
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(Token.SenderInDenyList.selector, receiver)
        );
        token.transferFrom(receiver, user1, 100);
    }

    function test_TransferFrom_RevertWhen_RecipientInDenyList() public {
        // Mint tokens
        vm.prank(minter);
        token.mint(receiver, 1000);

        // Approve user1
        vm.prank(receiver);
        token.approve(user1, 100);

        // Add user2 to deny list
        vm.prank(denyLister);
        token.addToDenyList(user2);

        // Try to transfer to denied address
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(Token.RecipientInDenyList.selector, user2)
        );
        token.transferFrom(receiver, user2, 100);
    }

    // ============ View Function Tests ============

    function test_Version() public view {
        assertEq(token.version(), "1.0.0");
    }

    function test_SupportsInterface() public view {
        // AccessControl interface ID
        bytes4 accessControlInterfaceId = 0x7965db0b;
        assertTrue(token.supportsInterface(accessControlInterfaceId));
    }

    function test_Decimals() public view {
        assertEq(token.decimals(), 18);
    }

    // ============ Fuzz Tests ============

    function testFuzz_Mint_ValidAmount(uint256 amount) public {
        vm.assume(amount > 0 && amount <= MAX_SUPPLY);

        vm.prank(minter);
        token.mint(receiver, amount);

        assertEq(token.balanceOf(receiver), amount);
    }

    function testFuzz_Burn_ValidAmount(uint256 mintAmount, uint256 burnAmount)
        public
    {
        vm.assume(mintAmount > 0 && mintAmount <= MAX_SUPPLY);
        vm.assume(burnAmount > 0 && burnAmount <= mintAmount);

        // Mint tokens
        vm.prank(minter);
        token.mint(receiver, mintAmount);

        // Transfer to minter
        vm.prank(receiver);
        token.transfer(minter, mintAmount);

        // Burn
        vm.prank(minter);
        token.burn(burnAmount);

        assertEq(token.balanceOf(minter), mintAmount - burnAmount);
    }
}

/**
 * @title TokenERC20Test
 * @notice Tests for ERC20 standard functionality
 */
contract TokenERC20Test is Test {
    Token public token;
    Proxy public proxy;

    address public admin;
    address public denyLister;
    address public minter;
    address public receiver;
    address public user1;
    address public user2;

    uint256 public constant DECIMALS = 18;
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10 ** DECIMALS;

    function setUp() public {
        admin = makeAddr("admin");
        denyLister = makeAddr("denyLister");
        minter = makeAddr("minter");
        receiver = makeAddr("receiver");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        Token implementation = new Token();
        bytes memory initData = abi.encodeWithSelector(
            Token.initialize.selector,
            "Test Token",
            "TEST",
            admin,
            denyLister,
            minter,
            receiver,
            MAX_SUPPLY
        );
        proxy = new Proxy(address(implementation), admin, initData);
        token = Token(address(proxy));
    }

    function test_Transfer_Success() public {
        uint256 amount = 1000 * 10 ** DECIMALS;

        vm.prank(minter);
        token.mint(receiver, amount);

        vm.prank(receiver);
        token.transfer(user1, amount);

        assertEq(token.balanceOf(user1), amount);
        assertEq(token.balanceOf(receiver), 0);
    }

    function test_Approve_Success() public {
        uint256 amount = 1000 * 10 ** DECIMALS;

        vm.prank(receiver);
        token.approve(user1, amount);

        assertEq(token.allowance(receiver, user1), amount);
    }

    function test_TransferFrom_Success() public {
        uint256 amount = 1000 * 10 ** DECIMALS;

        vm.prank(minter);
        token.mint(receiver, amount);

        vm.prank(receiver);
        token.approve(user1, amount);

        vm.prank(user1);
        token.transferFrom(receiver, user2, amount);

        assertEq(token.balanceOf(user2), amount);
    }

    function test_TotalSupply_AfterMint() public {
        uint256 amount = 1000 * 10 ** DECIMALS;

        vm.prank(minter);
        token.mint(receiver, amount);

        assertEq(token.totalSupply(), amount);
    }
}
