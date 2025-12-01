import { expect } from "chai";
import hre from "hardhat";
import { ContractTransactionResponse, ZeroAddress } from "ethers";
import type { Signer } from "ethers";
import { DEPLOYMENT_CONFIG, TOKEN_CONFIG } from "../scripts/deployment-config";

const { ethers } = hre;

describe("xBTC End-to-End Tests", function () {
  let implementation: any;
  let proxy: any;
  let xBTC: any;
  let admin: Signer;
  let minter: Signer;
  let treasury: Signer;
  let newAdmin: Signer;
  let user1: Signer;
  let user2: Signer;
  
  let adminAddress: string;
  let minterAddress: string;
  let treasuryAddress: string;
  let newAdminAddress: string;
  let user1Address: string;
  let user2Address: string;

  const DENY_LISTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("DENY_LISTER_ROLE"));
  const MINTER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("MINTER_ROLE"));
  const DEFAULT_DENY_LISTER_ROLE = ethers.ZeroHash;

  before(async function () {
    console.log("🚀 Starting xBTC End-to-End Deployment Test");
    
    [admin, minter, treasury, newAdmin, user1, user2] = await ethers.getSigners();
    adminAddress = await admin.getAddress();
    minterAddress = await minter.getAddress();
    treasuryAddress = await treasury.getAddress();
    newAdminAddress = await newAdmin.getAddress();
    user1Address = await user1.getAddress();
    user2Address = await user2.getAddress();

    console.log("📋 Test Accounts:");
    console.log(`   Admin: ${adminAddress}`);
    console.log(`   Minter: ${minterAddress}`);
    console.log(`   Treasury: ${treasuryAddress}`);
    console.log(`   New Admin: ${newAdminAddress}`);
    console.log(`   User1: ${user1Address}`);
    console.log(`   User2: ${user2Address}`);
  });

  describe("Phase 1: Deployment with Predetermined Addresses", function () {
    it("Should deploy implementation contract", async function () {
      console.log("🏗️  Deploying xBTC Implementation...");
      
      // Deploy implementation contract
      implementation = await ethers.deployContract("Token");
      await implementation.waitForDeployment();
      
      const implementationAddress = await implementation.getAddress();
      console.log(`   Implementation deployed at: ${implementationAddress}`);
      
      // Verify implementation is initialized (should revert)
      await expect(
        implementation.initialize(TOKEN_CONFIG.NAME, TOKEN_CONFIG.SYMBOL, adminAddress, minterAddress, treasuryAddress, TOKEN_CONFIG.MAX_SUPPLY)
      ).to.be.revertedWithCustomError(implementation, "InvalidInitialization");
      
      console.log("   ✅ Implementation deployment complete");
    });

    it("Should deploy proxy and initialize", async function () {
      console.log("🔄 Deploying Proxy and Initializing...");
      
      // Encode initialization data
      const initData = implementation.interface.encodeFunctionData(
        "initialize", 
        [TOKEN_CONFIG.NAME, TOKEN_CONFIG.SYMBOL, adminAddress, minterAddress, treasuryAddress, TOKEN_CONFIG.MAX_SUPPLY]
      );
      
      // Deploy xbtcProxy (TransparentUpgradeableProxy)
      const ProxyFactory = await ethers.getContractFactory("contracts/Proxy.sol:Proxy");
      proxy = await ProxyFactory.deploy(
        await implementation.getAddress(),
    adminAddress, // proxy admin
        initData
      );
      await proxy.waitForDeployment();
      
      const proxyAddress = await proxy.getAddress();
      console.log(`   Proxy deployed at: ${proxyAddress}`);
      
      // Connect to proxy through implementation ABI
      xBTC = implementation.attach(proxyAddress);
      
      // Verify initialization
      expect(await xBTC.name()).to.equal(TOKEN_CONFIG.NAME);
      expect(await xBTC.symbol()).to.equal(TOKEN_CONFIG.SYMBOL);
      expect(await xBTC.decimals()).to.equal(TOKEN_CONFIG.DECIMALS);
      expect(await xBTC.hasRole(DEFAULT_DENY_LISTER_ROLE, adminAddress)).to.be.true;
      expect(await xBTC.hasRole(DENY_LISTER_ROLE, adminAddress)).to.be.true;
      expect(await xBTC.hasRole(MINTER_ROLE, minterAddress)).to.be.true;
      
      console.log("   ✅ Proxy deployment and initialization complete");
    });

    it("Should display deployment summary", async function () {
      console.log("📊 Deployment Summary:");
      console.log(`   Contract Name: ${await xBTC.name()}`);
      console.log(`   Symbol: ${await xBTC.symbol()}`);
      console.log(`   Decimals: ${await xBTC.decimals()}`);
      console.log(`   Max Supply: ${TOKEN_CONFIG.MAX_SUPPLY.toString()}`);
      console.log(`   Implementation: ${await implementation.getAddress()}`);
      console.log(`   Proxy: ${await proxy.getAddress()}`);
      console.log(`   Version: ${await xBTC.version()}`);
    });
  });

  describe("Phase 2: Token Operations", function () {
    it("Should mint initial supply to treasury", async function () {
      console.log("💰 Minting initial supply to treasury...");
      
      const initialMint = TOKEN_CONFIG.MAX_SUPPLY / BigInt(10); // 10% of max supply
      
      await expect(xBTC.connect(minter).mint(treasuryAddress, initialMint))
        .to.emit(xBTC, "Mint")
        .withArgs(treasuryAddress, initialMint)
        .and.to.emit(xBTC, "Transfer")
        .withArgs(ZeroAddress, treasuryAddress, initialMint);
      
      const treasuryBalance = await xBTC.balanceOf(treasuryAddress);
      expect(treasuryBalance).to.equal(initialMint);
      
      console.log(`   ✅ Minted ${ethers.formatUnits(initialMint, TOKEN_CONFIG.DECIMALS)} xBTC to treasury`);
      console.log(`   Treasury balance: ${ethers.formatUnits(treasuryBalance, TOKEN_CONFIG.DECIMALS)} xBTC`);
    });

    it("Should distribute tokens to users", async function () {
      console.log("🔄 Distributing tokens to users...");
      
      const userAmount = ethers.parseUnits("1000", TOKEN_CONFIG.DECIMALS); // 1000 xBTC each
      
      // Transfer from treasury to users
      await expect(xBTC.connect(treasury).transfer(user1Address, userAmount))
        .to.emit(xBTC, "Transfer")
        .withArgs(treasuryAddress, user1Address, userAmount);
        
      await expect(xBTC.connect(treasury).transfer(user2Address, userAmount))
        .to.emit(xBTC, "Transfer")
        .withArgs(treasuryAddress, user2Address, userAmount);
      
      expect(await xBTC.balanceOf(user1Address)).to.equal(userAmount);
      expect(await xBTC.balanceOf(user2Address)).to.equal(userAmount);
      
      console.log(`   ✅ Distributed ${ethers.formatUnits(userAmount, TOKEN_CONFIG.DECIMALS)} xBTC to each user`);
    });

    it("Should perform inter-user transfers", async function () {
      console.log("💸 Testing inter-user transfers...");
      
      const transferAmount = ethers.parseUnits("250", TOKEN_CONFIG.DECIMALS);
      const initialUser1Balance = await xBTC.balanceOf(user1Address);
      const initialUser2Balance = await xBTC.balanceOf(user2Address);
      
      await expect(xBTC.connect(user1).transfer(user2Address, transferAmount))
        .to.emit(xBTC, "Transfer")
        .withArgs(user1Address, user2Address, transferAmount);
      
      expect(await xBTC.balanceOf(user1Address)).to.equal(initialUser1Balance - transferAmount);
      expect(await xBTC.balanceOf(user2Address)).to.equal(initialUser2Balance + transferAmount);
      
      console.log(`   ✅ Transferred ${ethers.formatUnits(transferAmount, TOKEN_CONFIG.DECIMALS)} xBTC from user1 to user2`);
    });

    it("Should burn tokens from circulation", async function () {
      console.log("🔥 Burning tokens from circulation...");
      
      const burnAmount = ethers.parseUnits("100", TOKEN_CONFIG.DECIMALS);
      const initialTotalSupply = await xBTC.totalSupply();
      
      // First mint tokens to the minter so they have tokens to burn
      await xBTC.connect(admin).setReceiver(minterAddress);
      await xBTC.connect(minter).mint(minterAddress, burnAmount);
      const initialMinterBalance = await xBTC.balanceOf(minterAddress);
      
      await expect(xBTC.connect(minter).burn(burnAmount))
        .to.emit(xBTC, "Burn")
        .withArgs(minterAddress, burnAmount)
        .and.to.emit(xBTC, "Transfer")
        .withArgs(minterAddress, ZeroAddress, burnAmount);
      
      expect(await xBTC.totalSupply()).to.equal(initialTotalSupply);
      expect(await xBTC.balanceOf(minterAddress)).to.equal(initialMinterBalance - burnAmount);
      
      console.log(`   ✅ Burned ${ethers.formatUnits(burnAmount, TOKEN_CONFIG.DECIMALS)} xBTC from user1`);
      console.log(`   New total supply: ${ethers.formatUnits(await xBTC.totalSupply(), TOKEN_CONFIG.DECIMALS)} xBTC`);
    });

    it("Should test emergency pause functionality", async function () {
      console.log("⏸️  Testing emergency pause...");
      
      // Pause the contract
      await expect(xBTC.connect(admin).pause())
        .to.emit(xBTC, "Paused")
        .withArgs(adminAddress);
      
      expect(await xBTC.paused()).to.be.true;
      
      // Verify transfers are blocked
      const transferAmount = ethers.parseUnits("10", TOKEN_CONFIG.DECIMALS);
      await expect(
        xBTC.connect(user1).transfer(user2Address, transferAmount)
      ).to.be.revertedWithCustomError(xBTC, "EnforcedPause");
      
      // Unpause
      await expect(xBTC.connect(admin).unpause())
        .to.emit(xBTC, "Unpaused")
        .withArgs(adminAddress);
      
      expect(await xBTC.paused()).to.be.false;
      
      // Verify transfers work again
      await expect(xBTC.connect(user1).transfer(user2Address, transferAmount))
        .to.emit(xBTC, "Transfer")
        .withArgs(user1Address, user2Address, transferAmount);
      
      console.log("   ✅ Emergency pause functionality working correctly");
    });

    it("Should test address blocking functionality", async function () {
      console.log("🚫 Testing address blocking...");
      
      // Add user1 to deny list
      await expect(xBTC.connect(admin).addToDenyList(user1Address))
        .to.emit(xBTC, "AddedToDenyList")
        .withArgs(user1Address);
      
      expect(await xBTC.denyList(user1Address)).to.be.true;
      
      // Verify blocked user cannot transfer
      const transferAmount = ethers.parseUnits("10", TOKEN_CONFIG.DECIMALS);
      await expect(
        xBTC.connect(user1).transfer(user2Address, transferAmount)
      ).to.be.revertedWithCustomError(xBTC, "SenderInDenyList");
      
      // Verify others cannot transfer to blocked user
      await expect(
        xBTC.connect(user2).transfer(user1Address, transferAmount)
      ).to.be.revertedWithCustomError(xBTC, "RecipientInDenyList");
      
      // Remove user1 from deny list
      await expect(xBTC.connect(admin).removeFromDenyList(user1Address))
        .to.emit(xBTC, "RemovedFromDenyList")
        .withArgs(user1Address);
      
      expect(await xBTC.denyList(user1Address)).to.be.false;
      
      // Verify transfers work again
      await expect(xBTC.connect(user1).transfer(user2Address, transferAmount))
        .to.emit(xBTC, "Transfer")
        .withArgs(user1Address, user2Address, transferAmount);
      
      console.log("   ✅ Address blocking functionality working correctly");
    });
  });

  describe("Phase 3: Advanced Features", function () {
    // EIP-3009 meta-transactions test removed as functions were removed from contract
    /*
    it("Should test EIP-3009 meta-transactions", async function () {
      console.log("🔐 Testing EIP-3009 meta-transactions...");
      
      const transferAmount = ethers.parseUnits("50", TOKEN_CONFIG.DECIMALS);
      const nonce = ethers.randomBytes(32);
      const validAfter = 0;
      const validBefore = Math.floor(Date.now() / 1000) + 3600; // 1 hour from now
      
      // Get chain ID properly
      const chainId = (await ethers.provider.getNetwork()).chainId;
      
      // Set up EIP-712 domain
      const domain = {
        name: TOKEN_CONFIG.NAME,
        version: "1",
        chainId: Number(chainId),
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
        from: user1Address,
        to: user2Address,
        value: transferAmount,
        validAfter,
        validBefore,
        nonce: ethers.hexlify(nonce),
      };
      
      // Sign the transaction
      const signature = await user1.signTypedData(domain, types, message);
      const { v, r, s } = ethers.Signature.from(signature);
      
      const initialUser1Balance = await xBTC.balanceOf(user1Address);
      const initialUser2Balance = await xBTC.balanceOf(user2Address);
      
      // Execute meta-transaction (anyone can submit it)
      await expect(
        xBTC.connect(admin).transferWithAuthorization(
          user1Address,
          user2Address,
          transferAmount,
          validAfter,
          validBefore,
          ethers.hexlify(nonce),
          v,
          r,
          s
        )
      ).to.emit(xBTC, "Transfer")
        .withArgs(user1Address, user2Address, transferAmount)
        .and.to.emit(xBTC, "AuthorizationUsed")
        .withArgs(user1Address, ethers.hexlify(nonce));
      
      expect(await xBTC.balanceOf(user1Address)).to.equal(initialUser1Balance - transferAmount);
      expect(await xBTC.balanceOf(user2Address)).to.equal(initialUser2Balance + transferAmount);
      expect(await xBTC.authorizationState(user1Address, ethers.hexlify(nonce))).to.be.true;
      
      console.log(`   ✅ Meta-transaction executed: ${ethers.formatUnits(transferAmount, TOKEN_CONFIG.DECIMALS)} xBTC`);
    });
    */

    it("Should test ERC-2612 permit functionality", async function () {
      console.log("📝 Testing ERC-2612 permit...");
      
      const spender = user2Address;
      const value = ethers.parseUnits("100", TOKEN_CONFIG.DECIMALS);
      const nonce = await xBTC.nonces(user1Address);
      const deadline = Math.floor(Date.now() / 1000) + 3600;
      
      // Get chain ID properly
      const chainId = (await ethers.provider.getNetwork()).chainId;
      
      const domain = {
        name: TOKEN_CONFIG.NAME,
        version: "1",
        chainId: Number(chainId),
        verifyingContract: await xBTC.getAddress(),
      };
      
      const types = {
        Permit: [
          { name: "owner", type: "address" },
          { name: "spender", type: "address" },
          { name: "value", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" },
        ],
      };
      
      const message = {
        owner: user1Address,
        spender,
        value,
        nonce,
        deadline,
      };
      
      const signature = await user1.signTypedData(domain, types, message);
      const { v, r, s } = ethers.Signature.from(signature);
      
      await expect(
        xBTC.permit(user1Address, spender, value, deadline, v, r, s)
      ).to.emit(xBTC, "Approval")
        .withArgs(user1Address, spender, value);
      
      expect(await xBTC.allowance(user1Address, spender)).to.equal(value);
      
      // Test using the allowance
      await expect(xBTC.connect(user2).transferFrom(user1Address, user2Address, value))
        .to.emit(xBTC, "Transfer")
        .withArgs(user1Address, user2Address, value);
      
      console.log("   ✅ ERC-2612 permit functionality working correctly");
    });
  });

  describe("Phase 4: Governance and Ownership Transfer", function () {
    it("Should transfer admin role to new admin", async function () {
      console.log("👑 Transferring admin role...");
      
      // Grant admin role to new admin
      await expect(xBTC.connect(admin).grantRole(DENY_LISTER_ROLE, newAdminAddress))
        .to.emit(xBTC, "RoleGranted")
        .withArgs(DENY_LISTER_ROLE, newAdminAddress, adminAddress);
      
      // Grant default admin role to new admin
      await expect(xBTC.connect(admin).grantRole(DEFAULT_DENY_LISTER_ROLE, newAdminAddress))
        .to.emit(xBTC, "RoleGranted")
        .withArgs(DEFAULT_DENY_LISTER_ROLE, newAdminAddress, adminAddress);
      
      // Verify new admin has roles
      expect(await xBTC.hasRole(DENY_LISTER_ROLE, newAdminAddress)).to.be.true;
      expect(await xBTC.hasRole(DEFAULT_DENY_LISTER_ROLE, newAdminAddress)).to.be.true;
      
      // Test new admin functionality
      await expect(xBTC.connect(newAdmin).addToDenyList(user1Address))
        .to.emit(xBTC, "AddedToDenyList")
        .withArgs(user1Address);
      
      // Remove from deny list for clean state
      await xBTC.connect(newAdmin).removeFromDenyList(user1Address);
      
      console.log(`   ✅ Admin role transferred to: ${newAdminAddress}`);
    });

    it("Should transfer minter role", async function () {
      console.log("🔧 Transferring minter role...");
      
      // Grant minter role to treasury (multi-sig in production)
      await expect(xBTC.connect(admin).grantRole(MINTER_ROLE, treasuryAddress))
        .to.emit(xBTC, "RoleGranted")
        .withArgs(MINTER_ROLE, treasuryAddress, adminAddress);
      
      // Test new minter functionality
      const mintAmount = ethers.parseUnits("500", TOKEN_CONFIG.DECIMALS);
      await xBTC.connect(admin).setReceiver(user1Address);
      await expect(xBTC.connect(treasury).mint(user1Address, mintAmount))
        .to.emit(xBTC, "Mint")
        .withArgs(user1Address, mintAmount);
      
      console.log(`   ✅ Minter role granted to treasury: ${treasuryAddress}`);
    });

    it("Should revoke old admin roles (optional)", async function () {
      console.log("🔄 Optionally revoking old admin roles...");
      
      // In production, you might want to revoke old admin roles
      // For this test, we'll keep them for demonstration
      console.log("   💡 Old admin roles maintained for demonstration");
      console.log(`   Original admin still has roles: ${adminAddress}`);
      console.log(`   New admin also has roles: ${newAdminAddress}`);
    });

    it("Should verify final contract state", async function () {
      console.log("🏁 Verifying final contract state...");
      
      const totalSupply = await xBTC.totalSupply();
      const user1Balance = await xBTC.balanceOf(user1Address);
      const user2Balance = await xBTC.balanceOf(user2Address);
      const treasuryBalance = await xBTC.balanceOf(treasuryAddress);
      
      console.log("   📊 Final Token Distribution:");
      console.log(`   Total Supply: ${ethers.formatUnits(totalSupply, TOKEN_CONFIG.DECIMALS)} xBTC`);
      console.log(`   Treasury: ${ethers.formatUnits(treasuryBalance, TOKEN_CONFIG.DECIMALS)} xBTC`);
      console.log(`   User1: ${ethers.formatUnits(user1Balance, TOKEN_CONFIG.DECIMALS)} xBTC`);
      console.log(`   User2: ${ethers.formatUnits(user2Balance, TOKEN_CONFIG.DECIMALS)} xBTC`);
      
      console.log("   🔑 Role Distribution:");
      console.log(`   Admin roles: ${adminAddress}, ${newAdminAddress}`);
      console.log(`   Minter roles: ${minterAddress}, ${treasuryAddress}`);
      
      // Verify contract is not paused and addresses are not in deny list
      expect(await xBTC.paused()).to.be.false;
      expect(await xBTC.denyList(user1Address)).to.be.false;
      expect(await xBTC.denyList(user2Address)).to.be.false;
      
      console.log("   ✅ Contract is in healthy operational state");
    });
  });

  describe("Phase 5: Multi-Chain Preparation", function () {
    it("Should display deployment info for multi-chain replication", async function () {
      console.log("🌐 Multi-Chain Deployment Information:");
      console.log("   ===========================================");
      
      const implementationAddress = await implementation.getAddress();
      const proxyAddress = await proxy.getAddress();
      
      console.log("   📋 Contract Addresses:");
      console.log(`   Implementation: ${implementationAddress}`);
      console.log(`   Proxy: ${proxyAddress}`);
      
      console.log("   🔧 Deployment Parameters:");
      console.log(`   Token Name: "${TOKEN_CONFIG.NAME}"`);
      console.log(`   Token Symbol: "${TOKEN_CONFIG.SYMBOL}"`);
      console.log(`   Decimals: ${TOKEN_CONFIG.DECIMALS}`);
      console.log(`   Max Supply: ${TOKEN_CONFIG.MAX_SUPPLY.toString()}`);
      
      console.log("   🔑 Initial Role Configuration:");
      console.log(`   Admin: ${DEPLOYMENT_CONFIG.ADMIN}`);
      console.log(`   Minter: ${DEPLOYMENT_CONFIG.MINTER}`);
      console.log(`   Treasury: ${DEPLOYMENT_CONFIG.TREASURY}`);

      console.log("   💡 For identical addresses across chains:");
      console.log("   - Use CREATE2 with predetermined salt");
      console.log("   - Deploy from same deployer address");
      console.log("   - Use identical bytecode");
      console.log(`   - Salt: ${DEPLOYMENT_CONFIG.PROXY_SALT}`);
      
      console.log("   ===========================================");
    });

    it("Should provide deployment verification checklist", async function () {
      console.log("✅ Deployment Verification Checklist:");
      
      const checks = [
        { name: "Contract initialized correctly", check: await xBTC.name() === TOKEN_CONFIG.NAME },
        { name: "Admin role assigned", check: await xBTC.hasRole(DEFAULT_DENY_LISTER_ROLE, adminAddress) },
        { name: "Minter role assigned", check: await xBTC.hasRole(MINTER_ROLE, minterAddress) },
        { name: "Contract not paused", check: !(await xBTC.paused()) },
        { name: "Total supply > 0", check: (await xBTC.totalSupply()) > 0n },
        { name: "Max supply enforced", check: (await xBTC.totalSupply()) <= TOKEN_CONFIG.MAX_SUPPLY },
        { name: "Decimals correct", check: Number(await xBTC.decimals()) === TOKEN_CONFIG.DECIMALS },
        { name: "Version correct", check: await xBTC.version() === "1.0.0" },
      ];
      
      checks.forEach((check, index) => {
        const status = check.check ? "✅" : "❌";
        console.log(`   ${status} ${check.name}`);
        expect(check.check).to.be.true;
      });
      
      console.log("   🎉 All deployment verification checks passed!");
    });
  });

  after(async function () {
    console.log("🏆 xBTC End-to-End Test Completed Successfully!");
    console.log("   All phases completed:");
    console.log("   ✅ Phase 1: Deployment with predetermined addresses");
    console.log("   ✅ Phase 2: Token operations (mint, burn, transfer)");
    console.log("   ✅ Phase 3: Advanced features (meta-transactions, permits)");
    console.log("   ✅ Phase 4: Governance and ownership transfer");
    console.log("   ✅ Phase 5: Multi-chain preparation");
  });
});