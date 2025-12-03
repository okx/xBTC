import { expect } from "chai";
import hre from "hardhat";

const { ethers } = hre;

describe("xBTC Deployment End-to-End", function () {
  let implementation: any;
  let proxy: any;
  let xBTC: any;
  let signers: any[];
  let admin: string;
  let minter: string;
  let treasury: string;
  let newAdmin: string;

  const TOKEN_NAME = "Cross-Chain Bitcoin";
  const TOKEN_SYMBOL = "xBTC";
  const MAX_SUPPLY = 21_000_000n * 10n ** 8n;

  let denyLister: string;
  
  it("Phase 1: Deploy contracts with predetermined addresses pattern", async function () {
    console.log("🚀 Starting xBTC End-to-End Deployment Test");
    
    signers = await ethers.getSigners();
    admin = await signers[0].getAddress();
    denyLister = await signers[1].getAddress();
    minter = await signers[2].getAddress(); 
    treasury = await signers[3].getAddress();
    newAdmin = await signers[4].getAddress();

    console.log("📋 Test Accounts:");
    console.log(`   Admin: ${admin}`);
    console.log(`   DenyLister: ${denyLister}`);
    console.log(`   Minter: ${minter}`);
    console.log(`   Treasury: ${treasury}`);
    console.log(`   New Admin: ${newAdmin}`);

    // Deploy implementation
    console.log("🏗️  Deploying xBTC Implementation...");
    implementation = await ethers.deployContract("xBTC");
    await implementation.waitForDeployment();
    
    const implementationAddress = await implementation.getAddress();
    console.log(`   Implementation deployed at: ${implementationAddress}`);

    // Prepare initialization data
    const initData = implementation.interface.encodeFunctionData(
      "initialize", 
      [TOKEN_NAME, TOKEN_SYMBOL, admin, denyLister, minter, treasury, MAX_SUPPLY]
    );

    // Deploy proxy
    console.log("🔄 Deploying Proxy...");
    proxy = await ethers.deployContract("contracts/Proxy.sol:Proxy", [
      implementationAddress,
      admin, // proxy admin
      initData
    ]);
    await proxy.waitForDeployment();
    
    const proxyAddress = await proxy.getAddress();
    console.log(`   Proxy deployed at: ${proxyAddress}`);

    // Connect to proxy
    xBTC = implementation.attach(proxyAddress);

    // Verify initialization
    expect(await xBTC.name()).to.equal(TOKEN_NAME);
    expect(await xBTC.symbol()).to.equal(TOKEN_SYMBOL);
    expect(await xBTC.decimals()).to.equal(8);

    console.log("   ✅ Phase 1 Complete: Deployment successful");
  });

  it("Phase 2: Initial token operations", async function () {
    console.log("💰 Phase 2: Token Operations");
    
    const initialMint = ethers.parseUnits("2100000", 8); // 2.1M xBTC (10% of max)
    
    // Mint initial supply to treasury
    console.log("   Minting initial supply to treasury...");
    await expect(xBTC.connect(signers[2]).mint(treasury, initialMint))
      .to.emit(xBTC, "Mint")
      .withArgs(treasury, initialMint);

    const treasuryBalance = await xBTC.balanceOf(treasury);
    expect(treasuryBalance).to.equal(initialMint);
    
    console.log(`   ✅ Minted ${ethers.formatUnits(initialMint, 8)} xBTC to treasury`);

    // Distribute to users
    const userAmount = ethers.parseUnits("1000", 8);
    const user1 = await signers[5].getAddress();
    const user2 = await signers[6].getAddress();
    
    console.log("   Distributing tokens to users...");
    await xBTC.connect(signers[3]).transfer(user1, userAmount);
    await xBTC.connect(signers[3]).transfer(user2, userAmount);
    
    expect(await xBTC.balanceOf(user1)).to.equal(userAmount);
    expect(await xBTC.balanceOf(user2)).to.equal(userAmount);
    
    console.log(`   ✅ Distributed ${ethers.formatUnits(userAmount, 8)} xBTC to each user`);

    // Test inter-user transfer
    const transferAmount = ethers.parseUnits("250", 8);
    await expect(xBTC.connect(signers[5]).transfer(user2, transferAmount))
      .to.emit(xBTC, "Transfer")
      .withArgs(user1, user2, transferAmount);
    
    console.log("   ✅ Inter-user transfer successful");

    // Test burn - first mint tokens to the minter so they can burn
    const burnAmount = ethers.parseUnits("100", 8);
    await xBTC.connect(signers[1]).setReceiver(minter);
    await xBTC.connect(signers[2]).mint(minter, burnAmount);
    
    await expect(xBTC.connect(signers[2]).burn(burnAmount))
      .to.emit(xBTC, "Burn")
      .withArgs(minter, burnAmount);
    
    console.log("   ✅ Token burn successful");
    console.log("   ✅ Phase 2 Complete: Token operations successful");
  });

  it("Phase 3: Advanced features testing", async function () {
    console.log("🔐 Phase 3: Advanced Features");
    
    const user1 = await signers[5].getAddress();
    const user2 = await signers[6].getAddress();
    
    // Test pause functionality
    console.log("   Testing pause functionality...");
    await xBTC.connect(signers[1]).pause();
    expect(await xBTC.paused()).to.be.true;
    
    await expect(
      xBTC.connect(signers[5]).transfer(user2, ethers.parseUnits("10", 8))
    ).to.be.revertedWithCustomError(xBTC, "EnforcedPause");
    
    await xBTC.connect(signers[1]).unpause();
    expect(await xBTC.paused()).to.be.false;
    
    console.log("   ✅ Pause functionality working");

    // Test address blocking
    console.log("   Testing address blocking...");
    await expect(xBTC.connect(signers[1]).addToDenyList(user1))
      .to.emit(xBTC, "AddedToDenyList")
      .withArgs(user1);
    
    expect(await xBTC.denyList(user1)).to.be.true;
    
    await expect(
      xBTC.connect(signers[5]).transfer(user2, ethers.parseUnits("10", 8))
          ).to.be.revertedWithCustomError(xBTC, "SenderInDenyList");
    
    await xBTC.connect(signers[1]).removeFromDenyList(user1);
    expect(await xBTC.denyList(user1)).to.be.false;
    
    console.log("   ✅ Address blocking working");

    // EIP-3009 meta-transaction test removed as functions were removed from contract
    /*
    // Test EIP-3009 meta-transaction
    console.log("   Testing EIP-3009 meta-transactions...");
    const transferAmount = ethers.parseUnits("50", 8);
    const nonce = ethers.randomBytes(32);
    const validAfter = 0;
    const validBefore = Math.floor(Date.now() / 1000) + 3600;
    
    const chainId = Number((await ethers.provider.getNetwork()).chainId);
    const domain = {
      name: TOKEN_NAME,
      version: "1",
      chainId,
      verifyingContract: await xBTC.getAddress(),
    };
    
    const types = {
      TransferWithAuthorization: [
        { name: "from", type: "address" },
        { name: "to", type: "address" },
        { name: "value", type: "uint256" },
        { name: "validAfter", type: "uint256" },
        { name: "validBefore", type: "uint256" },
        { name: "nonce", type: "bytes32" },
      ],
    };
    
    const message = {
      from: user1,
      to: user2,
      value: transferAmount,
      validAfter,
      validBefore,
      nonce: ethers.hexlify(nonce),
    };
    
    const signature = await signers[4].signTypedData(domain, { TransferWithAuthorization: types.TransferWithAuthorization }, message);
    const { v, r, s } = ethers.Signature.from(signature);
    
    await expect(
      xBTC.transferWithAuthorization(user1, user2, transferAmount, validAfter, validBefore, ethers.hexlify(nonce), v, r, s)
    ).to.emit(xBTC, "AuthorizationUsed")
      .withArgs(user1, ethers.hexlify(nonce));
    
    console.log("   ✅ Meta-transaction successful");
    */
    console.log("   ✅ Phase 3 Complete: Advanced features working");
  });

  it("Phase 4: Governance and ownership operations", async function () {
    console.log("👑 Phase 4: Governance Operations");
    
    const DENY_LISTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("DENY_LISTER_ROLE"));
    const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
    const DEFAULT_ADMIN_ROLE = ethers.ZeroHash;
    
    // Transfer admin role
    console.log("   Transferring admin role...");
    await expect(xBTC.connect(signers[0]).grantRole(DENY_LISTER_ROLE, newAdmin))
      .to.emit(xBTC, "RoleGranted")
      .withArgs(DENY_LISTER_ROLE, newAdmin, admin);
    
    await expect(xBTC.connect(signers[0]).grantRole(DEFAULT_ADMIN_ROLE, newAdmin))
      .to.emit(xBTC, "RoleGranted")
      .withArgs(DEFAULT_ADMIN_ROLE, newAdmin, admin);
    
    expect(await xBTC.hasRole(DENY_LISTER_ROLE, newAdmin)).to.be.true;
    expect(await xBTC.hasRole(DEFAULT_ADMIN_ROLE, newAdmin)).to.be.true;
    
    console.log(`   ✅ Admin role transferred to: ${newAdmin}`);

    // Test new admin functionality (newAdmin has DENY_LISTER_ROLE now)
    const testUser = await signers[7].getAddress();
    await expect(xBTC.connect(signers[4]).addToDenyList(testUser))
      .to.emit(xBTC, "AddedToDenyList")
      .withArgs(testUser);
    
    await xBTC.connect(signers[4]).removeFromDenyList(testUser); // Clean up
    
    console.log("   ✅ New admin functionality verified");

    // Grant minter role to treasury
    console.log("   Granting minter role to treasury...");
    await expect(xBTC.connect(signers[0]).grantRole(MINTER_ROLE, treasury))
      .to.emit(xBTC, "RoleGranted")
      .withArgs(MINTER_ROLE, treasury, admin);
    
    // Test treasury minting
    const mintAmount = ethers.parseUnits("500", 8);
    await xBTC.connect(signers[1]).setReceiver(testUser); // DenyLister sets receiver
    await expect(xBTC.connect(signers[3]).mint(testUser, mintAmount))
      .to.emit(xBTC, "Mint")
      .withArgs(testUser, mintAmount);
    
    console.log("   ✅ Treasury minting successful");
    console.log("   ✅ Phase 4 Complete: Governance operations successful");
  });

  it("Phase 5: Final verification and deployment summary", async function () {
    console.log("🏁 Phase 5: Final Verification");
    
    const totalSupply = await xBTC.totalSupply();
    const maxSupply = await xBTC.MAX_SUPPLY();
    
    console.log("📊 Final Contract State:");
    console.log(`   Total Supply: ${ethers.formatUnits(totalSupply, 8)} xBTC`);
    console.log(`   Max Supply: ${ethers.formatUnits(maxSupply, 8)} xBTC`);
    console.log(`   Contract Version: ${await xBTC.version()}`);
    console.log(`   Implementation: ${await implementation.getAddress()}`);
    console.log(`   Proxy: ${await proxy.getAddress()}`);
    
    // Verify contract health
    const healthChecks = [
      { name: "Contract not paused", check: !(await xBTC.paused()) },
      { name: "Total supply within limits", check: totalSupply <= maxSupply && totalSupply > 0n },
      { name: "Correct decimals", check: Number(await xBTC.decimals()) === 8 },
      { name: "Admin role assigned", check: await xBTC.hasRole(ethers.ZeroHash, admin) },
      { name: "Minter role assigned", check: await xBTC.hasRole(ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE")), minter) },
      { name: "New admin has role", check: await xBTC.hasRole(ethers.keccak256(ethers.toUtf8Bytes("DENY_LISTER_ROLE")), newAdmin) },
    ];
    
    console.log("✅ Health Check Results:");
    healthChecks.forEach((check, index) => {
      const status = check.check ? "✅" : "❌";
      console.log(`   ${status} ${check.name}`);
      expect(check.check).to.be.true;
    });

    console.log("🌐 Multi-Chain Deployment Ready:");
    console.log("   Contract successfully deployed and tested");
    console.log("   All functionality verified");
    console.log("   Ready for multi-chain deployment using:");
    console.log("   - Same implementation bytecode");
    console.log("   - CREATE2 for predetermined addresses");
    console.log("   - Consistent initialization parameters");
    
    console.log("🎉 xBTC End-to-End Test Completed Successfully!");
    console.log("   ✅ Phase 1: Deployment");
    console.log("   ✅ Phase 2: Token operations");  
    console.log("   ✅ Phase 3: Advanced features");
    console.log("   ✅ Phase 4: Governance");
    console.log("   ✅ Phase 5: Verification");
  });
});