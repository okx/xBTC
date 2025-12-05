// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "./Deploy.xETH.s.sol";

/**
 * @title TestXETH
 * @notice Comprehensive test script for xETH token
 * Tests all functions of the xToken contract after deployment
 */
contract TestXETH is Script {
    xETH public implementation;
    Proxy public proxy;
    xToken public token;
    
    // Two addresses strategy - both with private keys
    // - admin: deployer with private key, for deployment and management
    // - testAccount: test user with private key, for testing transactions
    uint256 public adminPK;
    uint256 public testAccountPK;
    address public admin;
    address public testAccount;
    
    function run() external {
        // Read private keys from environment
        adminPK = vm.envUint("ADMIN_PK");
        testAccountPK = vm.envUint("TEST_ACCOUNT_PK");
        
        // Derive addresses from private keys
        admin = vm.addr(adminPK);
        testAccount = vm.addr(testAccountPK);
        
        console.log("\n=== Starting xETH Comprehensive Test ===\n");
        console.log("Admin (Deployer):", admin);
        console.log("Test Account:", testAccount);
        console.log("");
        
        // Step 1: Deploy contracts
        deployContracts();
        
        // Step 2: Test all read functions
        testReadFunctions();
        
        // Step 3: Test minting
        testMinting();
        
        // Step 4: Test ERC20 transfers
        testTransfers();
        
        // Step 5: Test ERC20 approvals
        testApprovals();
        
        // Step 6: Test pause/unpause
        testPauseUnpause();
        
        // Step 7: Test deny list functions
        testDenyList();
        
        // Step 8: Test batch deny list operations
        testBatchDenyList();
        
        // Step 9: Test receiver management
        testReceiverManagement();
        
        // Step 10: Test role transfers
        testRoleTransfers();
        
        // Step 11: Test burning
        testBurning();
        
        console.log("\n=== All Tests Completed Successfully! ===\n");
    }
    
    function deployContracts() internal {
        console.log(">>> Test 1: Deploying Contracts");
        
        vm.startBroadcast(adminPK);
        
        // Deploy implementation
        implementation = new xETH();
        console.log("Implementation deployed at:", address(implementation));
        
        // Prepare initialization data
        // admin gets all roles: DEFAULT_ADMIN_ROLE, DENY_LISTER_ROLE, MINTER_ROLE
        // admin is also the authorized receiver
        bytes memory initData = abi.encodeCall(
            xToken.initialize,
            (
                "xETH",
                "xETH",
                admin,          // DEFAULT_ADMIN_ROLE
                admin,          // DENY_LISTER_ROLE
                admin,          // MINTER_ROLE
                admin,          // authorized receiver
                100_000_000 * 10 ** 18
            )
        );
        
        // Deploy proxy
        proxy = new Proxy(address(implementation), admin, initData);
        console.log("Proxy deployed at:", address(proxy));
        
        token = xToken(address(proxy));
        
        vm.stopBroadcast();
        
        console.log("[PASS] Deployment successful\n");
    }
    
    function testReadFunctions() internal view {
        console.log(">>> Test 2: Testing Read Functions");
        
        // Test name()
        string memory name = token.name();
        console.log("name():", name);
        require(keccak256(bytes(name)) == keccak256(bytes("xETH")), "Name mismatch");
        
        // Test symbol()
        string memory symbol = token.symbol();
        console.log("symbol():", symbol);
        require(keccak256(bytes(symbol)) == keccak256(bytes("xETH")), "Symbol mismatch");
        
        // Test decimals()
        uint8 decimals = token.decimals();
        console.log("decimals():", decimals);
        require(decimals == 18, "Decimals mismatch");
        
        // Test totalSupply()
        uint256 supply = token.totalSupply();
        console.log("totalSupply():", supply);
        require(supply == 0, "Initial supply should be 0");
        
        // Test MAX_SUPPLY()
        uint256 maxSupply = token.MAX_SUPPLY();
        console.log("MAX_SUPPLY():", maxSupply);
        require(maxSupply == 100_000_000 * 10 ** 18, "Max supply mismatch");
        
        // Test authorizedReceiver()
        address authReceiver = token.authorizedReceiver();
        console.log("authorizedReceiver():", authReceiver);
        require(authReceiver == admin, "Receiver mismatch");
        
        // Test hasRole() for all roles - admin should have all roles
        bool hasAdminRole = token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin);
        console.log("hasRole(DEFAULT_ADMIN_ROLE, admin):", hasAdminRole);
        require(hasAdminRole, "Admin role check failed");
        
        bool hasMinterRole = token.hasRole(token.MINTER_ROLE(), admin);
        console.log("hasRole(MINTER_ROLE, admin):", hasMinterRole);
        require(hasMinterRole, "Minter role check failed");
        
        bool hasDenyListerRole = token.hasRole(token.DENY_LISTER_ROLE(), admin);
        console.log("hasRole(DENY_LISTER_ROLE, admin):", hasDenyListerRole);
        require(hasDenyListerRole, "DenyLister role check failed");
        
        // Test paused()
        bool isPaused = token.paused();
        console.log("paused():", isPaused);
        require(!isPaused, "Should not be paused initially");
        
        // Test version()
        string memory ver = token.version();
        console.log("version():", ver);
        require(keccak256(bytes(ver)) == keccak256(bytes("1.0.0")), "Version mismatch");
        
        // Test supportsInterface()
        bytes4 erc20Interface = 0x36372b07; // ERC20 interface ID
        bool supportsERC20 = token.supportsInterface(erc20Interface);
        console.log("supportsInterface(ERC20):", supportsERC20);
        
        console.log("[PASS] All read functions tested\n");
    }
    
    function testMinting() internal {
        console.log(">>> Test 3: Testing Minting");
        
        uint256 mintAmount = 1000 * 10 ** 18;
        
        // Admin mints to testAccount (admin is the authorizedReceiver initially)
        // First change receiver to testAccount, mint, then change back
        vm.startBroadcast(adminPK);
        token.setReceiver(testAccount);
        token.mint(testAccount, mintAmount);
        token.setReceiver(admin); // Set back to admin
        vm.stopBroadcast();
        
        uint256 balance = token.balanceOf(testAccount);
        console.log("Minted to testAccount:", mintAmount);
        console.log("TestAccount balance:", balance);
        require(balance == mintAmount, "Mint failed");
        
        console.log("[PASS] Minting successful\n");
    }
    
    function testTransfers() internal {
        console.log(">>> Test 4: Testing ERC20 Transfers");
        
        uint256 transferAmount = 100 * 10 ** 18;
        
        // TestAccount transfers tokens to admin
        vm.startBroadcast(testAccountPK);
        bool success = token.transfer(admin, transferAmount);
        vm.stopBroadcast();
        
        require(success, "Transfer failed");
        
        uint256 adminBalance = token.balanceOf(admin);
        uint256 testBalance = token.balanceOf(testAccount);
        console.log("Transferred from testAccount to admin:", transferAmount);
        console.log("Admin balance:", adminBalance);
        console.log("TestAccount balance:", testBalance);
        require(adminBalance == transferAmount, "Admin balance mismatch");
        
        console.log("[PASS] Transfer successful\n");
    }
    
    function testApprovals() internal {
        console.log(">>> Test 5: Testing ERC20 Approvals");
        
        uint256 approveAmount = 50 * 10 ** 18;
        
        // TestAccount approves admin to spend tokens
        vm.startBroadcast(testAccountPK);
        bool success = token.approve(admin, approveAmount);
        vm.stopBroadcast();
        
        require(success, "Approval failed");
        
        // Test allowance()
        uint256 allowance = token.allowance(testAccount, admin);
        console.log("TestAccount approved admin:", approveAmount);
        console.log("Allowance:", allowance);
        require(allowance == approveAmount, "Allowance mismatch");
        
        // Test transferFrom() - admin transfers from testAccount to admin
        uint256 transferAmount = 30 * 10 ** 18;
        uint256 adminBalanceBefore = token.balanceOf(admin);
        
        vm.startBroadcast(adminPK);
        bool transferSuccess = token.transferFrom(testAccount, admin, transferAmount);
        vm.stopBroadcast();
        
        require(transferSuccess, "TransferFrom failed");
        
        uint256 adminBalanceAfter = token.balanceOf(admin);
        console.log("Admin used transferFrom:", transferAmount);
        console.log("Admin balance after:", adminBalanceAfter);
        require(adminBalanceAfter == adminBalanceBefore + transferAmount, "TransferFrom balance mismatch");
        
        // Check remaining allowance
        uint256 remainingAllowance = token.allowance(testAccount, admin);
        console.log("Remaining allowance:", remainingAllowance);
        require(remainingAllowance == approveAmount - transferAmount, "Remaining allowance mismatch");
        
        console.log("[PASS] Approvals and transferFrom successful\n");
    }
    
    function testPauseUnpause() internal {
        console.log(">>> Test 6: Testing Pause/Unpause");
        
        // Admin has DENY_LISTER_ROLE, so it can pause/unpause
        vm.startBroadcast(adminPK);
        
        // Test pause()
        token.pause();
        bool isPaused = token.paused();
        console.log("After pause(), paused():", isPaused);
        require(isPaused, "Pause failed");
        
        // Test unpause()
        token.unpause();
        bool isUnpaused = !token.paused();
        console.log("After unpause(), not paused:", isUnpaused);
        require(isUnpaused, "Unpause failed");
        
        vm.stopBroadcast();
        
        console.log("[PASS] Pause/Unpause successful\n");
    }
    
    function testDenyList() internal {
        console.log(">>> Test 7: Testing Deny List Functions");
        
        // Create a dummy address for testing (won't use it for transactions)
        address testDenyUser = address(0x1234);
        
        // Test addToDenyList() - admin has DENY_LISTER_ROLE
        vm.startBroadcast(adminPK);
        token.addToDenyList(testDenyUser);
        vm.stopBroadcast();
        
        bool isInDenyList = token.denyList(testDenyUser);
        console.log("Added to deny list:", testDenyUser);
        console.log("denyList(testDenyUser):", isInDenyList);
        require(isInDenyList, "Add to deny list failed");
        
        // Test removeFromDenyList()
        vm.startBroadcast(adminPK);
        token.removeFromDenyList(testDenyUser);
        vm.stopBroadcast();
        
        bool isRemoved = !token.denyList(testDenyUser);
        console.log("Removed from deny list:", testDenyUser);
        console.log("Not in deny list:", isRemoved);
        require(isRemoved, "Remove from deny list failed");
        
        console.log("[PASS] Deny list functions successful\n");
    }
    
    function testBatchDenyList() internal {
        console.log(">>> Test 8: Testing Batch Deny List Operations");
        
        // Create dummy addresses for testing (won't use them for transactions)
        address[] memory accounts = new address[](3);
        accounts[0] = address(0x1111);
        accounts[1] = address(0x2222);
        accounts[2] = address(0x3333);
        
        // Test batchAddToDenyList()
        vm.startBroadcast(adminPK);
        token.batchAddToDenyList(accounts);
        vm.stopBroadcast();
        
        console.log("Batch added to deny list:");
        for (uint256 i = 0; i < accounts.length; i++) {
            bool isInList = token.denyList(accounts[i]);
            console.log("  Account", i, ":", isInList);
            require(isInList, "Batch add to deny list failed");
        }
        
        // Test batchRemoveFromDenyList()
        vm.startBroadcast(adminPK);
        token.batchRemoveFromDenyList(accounts);
        vm.stopBroadcast();
        
        console.log("Batch removed from deny list:");
        for (uint256 i = 0; i < accounts.length; i++) {
            bool isRemoved = !token.denyList(accounts[i]);
            console.log("  Account", i, " removed:", isRemoved);
            require(isRemoved, "Batch remove from deny list failed");
        }
        
        console.log("[PASS] Batch deny list operations successful\n");
    }
    
    function testReceiverManagement() internal {
        console.log(">>> Test 9: Testing Receiver Management");
        
        address currentReceiver = token.authorizedReceiver();
        console.log("Current receiver:", currentReceiver);
        require(currentReceiver == admin, "Initial receiver mismatch");
        
        // Admin can call setReceiver since it has DENY_LISTER_ROLE
        vm.startBroadcast(adminPK);
        token.setReceiver(testAccount);
        vm.stopBroadcast();
        
        address newReceiver = token.authorizedReceiver();
        console.log("New receiver:", newReceiver);
        require(newReceiver == testAccount, "Set receiver failed");
        
        // Set back to admin
        vm.startBroadcast(adminPK);
        token.setReceiver(admin);
        vm.stopBroadcast();
        
        console.log("[PASS] Receiver management successful\n");
    }
    
    function testRoleTransfers() internal {
        console.log(">>> Test 10: Testing Role Transfers");
        
        // Test transferMinter - transfer MINTER_ROLE from admin to testAccount
        vm.startBroadcast(adminPK);
        token.transferMinter(testAccount);
        vm.stopBroadcast();
        
        bool adminHasMinter = token.hasRole(token.MINTER_ROLE(), admin);
        bool testHasMinter = token.hasRole(token.MINTER_ROLE(), testAccount);
        console.log("After transferMinter:");
        console.log("  Admin has MINTER_ROLE:", adminHasMinter);
        console.log("  TestAccount has MINTER_ROLE:", testHasMinter);
        require(!adminHasMinter && testHasMinter, "Transfer minter failed");
        
        // Transfer back
        vm.startBroadcast(testAccountPK);
        token.transferMinter(admin);
        vm.stopBroadcast();
        
        // Test transferDenyLister - transfer DENY_LISTER_ROLE from admin to testAccount
        vm.startBroadcast(adminPK);
        token.transferDenyLister(testAccount);
        vm.stopBroadcast();
        
        bool adminHasDenyLister = token.hasRole(token.DENY_LISTER_ROLE(), admin);
        bool testHasDenyLister = token.hasRole(token.DENY_LISTER_ROLE(), testAccount);
        console.log("After transferDenyLister:");
        console.log("  Admin has DENY_LISTER_ROLE:", adminHasDenyLister);
        console.log("  TestAccount has DENY_LISTER_ROLE:", testHasDenyLister);
        require(!adminHasDenyLister && testHasDenyLister, "Transfer denyLister failed");
        
        // Transfer back
        vm.startBroadcast(testAccountPK);
        token.transferDenyLister(admin);
        vm.stopBroadcast();
        
        console.log("[PASS] Role transfers successful\n");
    }
    
    function testBurning() internal {
        console.log(">>> Test 11: Testing Burning");
        
        uint256 burnAmount = 50 * 10 ** 18;
        
        uint256 balanceBefore = token.balanceOf(admin);
        uint256 supplyBefore = token.totalSupply();
        console.log("Admin balance before burn:", balanceBefore);
        console.log("Total supply before burn:", supplyBefore);
        
        // Test burn() - admin has MINTER_ROLE from testMinting
        vm.startBroadcast(adminPK);
        token.burn(burnAmount);
        vm.stopBroadcast();
        
        uint256 balanceAfter = token.balanceOf(admin);
        uint256 supplyAfter = token.totalSupply();
        console.log("Burned amount:", burnAmount);
        console.log("Admin balance after burn:", balanceAfter);
        console.log("Total supply after burn:", supplyAfter);
        
        require(balanceAfter == balanceBefore - burnAmount, "Burn balance mismatch");
        require(supplyAfter == supplyBefore - burnAmount, "Burn supply mismatch");
        
        console.log("[PASS] Burning successful\n");
    }
    
}

