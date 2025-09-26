import hre from "hardhat";
import {TOKEN_CONFIG} from "./deployment-config.ts";

const { ethers } = hre;

interface DeploymentResult {
  implementation: string;
  proxy: string;
  xBTC: string;
  config: {
    implementationAddress: string;
    proxyAddress: string;
    adminAddress: string;
    minterAddress: string;
    treasuryAddress: string;
  };
}

async function deployContract(): Promise<DeploymentResult> {
  console.log("🚀 Starting xBTC deployment...");

  // Get the deployer account
  const test_addresses = await ethers.getSigners();
  const deployer = test_addresses[0];
  const minter = test_addresses[1];
  const treasury = test_addresses[2];
  console.log("Deploying contracts with the account:", deployer);
  const balance = await deployer.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "ETH");

  // Deploy the implementation contract
  console.log("\n1. Deploying xbtc implementation...");
  const xbtcFactory = await ethers.getContractFactory("xbtc");
  const implementation = await xbtcFactory.deploy();
  await implementation.waitForDeployment();
  const implementationAddress = await implementation.getAddress();
  console.log("✅ xbtc implementation deployed to:", implementationAddress);

  // Prepare initialization data
  console.log("\n2. Preparing initialization data...");
  const initData = implementation.interface.encodeFunctionData("initialize", [
    TOKEN_CONFIG.NAME,
    TOKEN_CONFIG.SYMBOL,
    deployer.address,
    minter.address,
    treasury.address, // Initial receiver
  ]);
  console.log("✅ Initialization data prepared");

  // Deploy the proxy (TransparentUpgradeableProxy will automatically create ProxyAdmin)
  console.log("\n3. Deploying xbtcProxy (ProxyAdmin will be created automatically)...");
  const xbtcProxyFactory = await ethers.getContractFactory("xbtcProxy");
  const proxy = await xbtcProxyFactory.deploy(
    implementationAddress,
    deployer.address, // EOA admin - TransparentUpgradeableProxy will create ProxyAdmin automatically
    initData
  );
  await proxy.waitForDeployment();
  const proxyAddress = await proxy.getAddress();
  console.log("✅ xbtcProxy deployed to:", proxyAddress);

  // Verify deployment
  const xBTC = xbtcFactory.attach(proxyAddress);
  const name = await xBTC.name();
  const symbol = await xBTC.symbol();
  console.log("✅ Token verified:", name, symbol);

  return {
    implementation: implementationAddress,
    proxy: proxyAddress,
    xBTC: proxyAddress,
    config: {
      implementationAddress: implementationAddress,
      proxyAddress: proxyAddress,
      adminAddress: deployer.address, // EOA that owns the auto-created ProxyAdmin
      minterAddress: minter.address,
      treasuryAddress: treasury.address,
    }
  };
}

async function testMintFunction(contractAddress: string) {
  console.log("\n🪙 Testing mint functionality...");

  const [, minter] = await ethers.getSigners();
  const [ , , recipient] = await ethers.getSigners();
  const xbtcFactory = await ethers.getContractFactory("xbtc");
  const xBTC = xbtcFactory.attach(contractAddress).connect(minter);

  const amount = ethers.parseUnits("1000", 8); // 1000 xBTC

  try {
    console.log(`Minting ${ethers.formatUnits(amount, 8)} xBTC to ${recipient}...`);
    const tx = await xBTC.mint(recipient, amount);
    console.log("Mint tx hash:", tx.hash);
    await tx.wait();

    const balance = await xBTC.balanceOf(recipient);
    console.log(`✅ Mint successful! Balance: ${ethers.formatUnits(balance, 8)} xBTC`);
  } catch (error: any) {
    console.error("❌ Mint failed:", error.message);
    throw error;
  }
}

async function testBurnFunction(contractAddress: string) {
  console.log("\n🔥 Testing burn functionality...");

  const [, minter] = await ethers.getSigners();
  const [, , treasury] = await ethers.getSigners();
  const xbtcFactory = await ethers.getContractFactory("xbtc");
  const xBTC = xbtcFactory.attach(contractAddress).connect(minter);

  const burnAmount = ethers.parseUnits("500", 8); // 500 xBTC

  try {
    // First, mint tokens to the authorized receiver (treasury)
    console.log(`Minting ${ethers.formatUnits(burnAmount, 8)} xBTC to authorized receiver for burn test...`);
    const mintTx = await xBTC.mint(treasury.address, burnAmount);
    console.log("Mint tx hash:", mintTx.hash);
    await mintTx.wait();

    // Transfer tokens from receiver to minter so the minter can burn them
    const xBTCTreasury = xbtcFactory.attach(contractAddress).connect(treasury);
    console.log(`Transferring ${ethers.formatUnits(burnAmount, 8)} xBTC from receiver to minter...`);
    const transferTx = await xBTCTreasury.transfer(minter.address, burnAmount);
    console.log("Transfer tx hash:", transferTx.hash);
    await transferTx.wait();

    const balanceBefore = await xBTC.balanceOf(minter.address);
    console.log(`Current minter balance: ${ethers.formatUnits(balanceBefore, 8)} xBTC`);
    console.log(`Burning ${ethers.formatUnits(burnAmount, 8)} xBTC from minter's balance...`);

    const tx = await xBTC.burn(burnAmount);
    console.log("Burn tx hash:", tx.hash);
    await tx.wait();

    const balanceAfter = await xBTC.balanceOf(minter.address);
    console.log(`✅ Burn successful! Balance: ${ethers.formatUnits(balanceAfter, 8)} xBTC`);
    console.log(`Burned: ${ethers.formatUnits(balanceBefore - balanceAfter, 8)} xBTC`);
  } catch (error: any) {
    console.error("❌ Burn failed:", error.message);
    throw error;
  }
}

async function testAddToDenyList(contractAddress: string) {
  console.log("\n🚫 Testing addToDenyList functionality...");

  const [admin] = await ethers.getSigners();
  const xbtcFactory = await ethers.getContractFactory("xbtc");
  const xBTC = xbtcFactory.attach(contractAddress).connect(admin);

  const addressToBlock = "0x9999999999999999999999999999999999999999";

  try {
    console.log(`Adding address ${addressToBlock} to deny list...`);
    const tx = await xBTC.addToDenyList(addressToBlock);
    console.log("AddToDenyList tx hash:", tx.hash);
    await tx.wait();

    const isBlocked = await xBTC.isInDenyList(addressToBlock);
    console.log(`✅ Address added to deny list. Blocked: ${isBlocked}`);
  } catch (error: any) {
    console.error("❌ addToDenyList failed:", error.message);
    throw error;
  }
}

async function testRemoveFromDenyList(contractAddress: string) {
  console.log("\n✅ Testing removeFromDenyList functionality...");

  const [admin] = await ethers.getSigners();
  const xbtcFactory = await ethers.getContractFactory("xbtc");
  const xBTC = xbtcFactory.attach(contractAddress).connect(admin);

  const addressToUnblock = "0x9999999999999999999999999999999999999999";

  try {
    console.log(`Removing address ${addressToUnblock} from deny list...`);
    const tx = await xBTC.removeFromDenyList(addressToUnblock);
    console.log("RemoveFromDenyList tx hash:", tx.hash);
    await tx.wait();

    const isBlocked = await xBTC.isInDenyList(addressToUnblock);
    console.log(`✅ Address removed from deny list. Blocked: ${isBlocked}`);
  } catch (error: any) {
    console.error("❌ removeFromDenyList failed:", error.message);
    throw error;
  }
}

async function testBatchAddToDenyList(contractAddress: string) {
  console.log("\n🚫📦 Testing batchAddToDenyList functionality...");

  const [admin] = await ethers.getSigners();
  const xbtcFactory = await ethers.getContractFactory("xbtc");
  const xBTC = xbtcFactory.attach(contractAddress).connect(admin);

  const addressesToBlock = [
    "0x1111111111111111111111111111111111111111",
    "0x2222222222222222222222222222222222222222",
    "0x3333333333333333333333333333333333333333"
  ];

  try {
    console.log(`Adding ${addressesToBlock.length} addresses to deny list...`);
    const tx = await xBTC.batchAddToDenyList(addressesToBlock);
    console.log("BatchAddToDenyList tx hash:", tx.hash);
    await tx.wait();

    // Check if all addresses are blocked
    for (const address of addressesToBlock) {
      const isBlocked = await xBTC.isInDenyList(address);
      console.log(`Address ${address}: Blocked = ${isBlocked}`);
    }
    console.log("✅ All addresses added to deny list successfully");
  } catch (error: any) {
    console.error("❌ batchAddToDenyList failed:", error.message);
    throw error;
  }
}

async function testBatchRemoveFromDenyList(contractAddress: string) {
  console.log("\n✅📦 Testing batchRemoveFromDenyList functionality...");

  const [admin] = await ethers.getSigners();
  const xbtcFactory = await ethers.getContractFactory("xbtc");
  const xBTC = xbtcFactory.attach(contractAddress).connect(admin);

  const addressesToUnblock = [
    "0x1111111111111111111111111111111111111111",
    "0x2222222222222222222222222222222222222222",
    "0x3333333333333333333333333333333333333333"
  ];

  try {
    console.log(`Removing ${addressesToUnblock.length} addresses from deny list...`);
    const tx = await xBTC.batchRemoveFromDenyList(addressesToUnblock);
    console.log("BatchRemoveFromDenyList tx hash:", tx.hash);
    await tx.wait();

    // Check if all addresses are unblocked
    for (const address of addressesToUnblock) {
      const isBlocked = await xBTC.isInDenyList(address);
      console.log(`Address ${address}: Blocked = ${isBlocked}`);
    }
    console.log("✅ All addresses removed from deny list successfully");
  } catch (error: any) {
    console.error("❌ batchRemoveFromDenyList failed:", error.message);
    throw error;
  }
}

async function testPauseFunction(contractAddress: string) {
  console.log("\n⏸️ Testing pause functionality...");

  const [admin] = await ethers.getSigners();
  const xbtcFactory = await ethers.getContractFactory("xbtc");
  const xBTC = xbtcFactory.attach(contractAddress).connect(admin);

  try {
    console.log("Pausing contract...");
    const tx = await xBTC.pause();
    console.log("Pause tx hash:", tx.hash);
    await tx.wait();

    const isPaused = await xBTC.paused();
    console.log(`✅ Contract paused. Status: ${isPaused}`);
  } catch (error: any) {
    console.error("❌ Pause failed:", error.message);
    throw error;
  }
}

async function testUnpauseFunction(contractAddress: string) {
  console.log("\n▶️ Testing unpause functionality...");

  const [admin] = await ethers.getSigners();
  const xbtcFactory = await ethers.getContractFactory("xbtc");
  const xBTC = xbtcFactory.attach(contractAddress).connect(admin);

  try {
    console.log("Unpausing contract...");
    const tx = await xBTC.unpause();
    console.log("Unpause tx hash:", tx.hash);
    await tx.wait();

    const isPaused = await xBTC.paused();
    console.log(`✅ Contract unpaused. Status: ${isPaused}`);
  } catch (error: any) {
    console.error("❌ Unpause failed:", error.message);
    throw error;
  }
}

async function testTransferDenyLister(contractAddress: string) {
  console.log("\n🔄 Testing transferDenyLister functionality...");

  const [admin] = await ethers.getSigners();
  const xbtcFactory = await ethers.getContractFactory("xbtc");
  const xBTC = xbtcFactory.attach(contractAddress).connect(admin);

  const newDenyLister = "0x8888888888888888888888888888888888888888";

  try {
    console.log(`Transferring deny lister role to ${newDenyLister}...`);
    const tx = await xBTC.transferDenyLister(newDenyLister);
    console.log("TransferDenyLister tx hash:", tx.hash);
    await tx.wait();

    const DENY_LISTER_ROLE = await xBTC.DENY_LISTER_ROLE();
    const hasRole = await xBTC.hasRole(DENY_LISTER_ROLE, newDenyLister);
    console.log(`✅ Deny lister role transferred. New deny lister has role: ${hasRole}`);
  } catch (error: any) {
    console.error("❌ transferDenyLister failed:", error.message);
    throw error;
  }
}

async function testTransferMinter(contractAddress: string) {
  console.log("\n🔄 Testing transferMinter functionality...");

  const [, minter] = await ethers.getSigners();
  const xbtcFactory = await ethers.getContractFactory("xbtc");
  const xBTC = xbtcFactory.attach(contractAddress).connect(minter);

  const newMinter = "0x7777777777777777777777777777777777777777";

  try {
    console.log(`Transferring minter role to ${newMinter}...`);
    const tx = await xBTC.transferMinter(newMinter);
    console.log("TransferMinter tx hash:", tx.hash);
    await tx.wait();

    const MINTER_ROLE = await xBTC.MINTER_ROLE();
    const hasRole = await xBTC.hasRole(MINTER_ROLE, newMinter);
    console.log(`✅ Minter role transferred. New minter has role: ${hasRole}`);
  } catch (error: any) {
    console.error("❌ transferMinter failed:", error.message);
    throw error;
  }
}

async function runProcessTest() {
  try {
    console.log("=".repeat(60));
    console.log("🔬 XBTC COMPREHENSIVE PROCESS TEST");
    console.log("=".repeat(60));
    console.log(`Network: ${hre.network.name}`);
    console.log(`Chain ID: ${hre.network.config.chainId || 'unknown'}`);
    console.log("=".repeat(60));

    // Step 1: Deploy contracts
    const deployment = await deployContract();

    console.log("\n📋 DEPLOYMENT SUMMARY:");
    console.log("====================================");
    console.log("Implementation Address:", deployment.implementation);
    console.log("Proxy Address:", deployment.proxy);
    console.log("Admin Address (owns auto-created ProxyAdmin):", deployment.config.adminAddress);
    console.log("Minter Address:", deployment.config.minterAddress);
    console.log("Treasury Address:", deployment.config.treasuryAddress);
    console.log("Note: ProxyAdmin was automatically created by TransparentUpgradeableProxy");
    console.log("====================================");

    // Step 2: Test all functions
    await testMintFunction(deployment.xBTC);
    await testBurnFunction(deployment.xBTC);
    await testAddToDenyList(deployment.xBTC);
    await testRemoveFromDenyList(deployment.xBTC);
    await testBatchAddToDenyList(deployment.xBTC);
    await testBatchRemoveFromDenyList(deployment.xBTC);
    await testPauseFunction(deployment.xBTC);
    await testUnpauseFunction(deployment.xBTC);
    await testTransferDenyLister(deployment.xBTC);
    await testTransferMinter(deployment.xBTC);

    console.log("\n" + "=".repeat(60));
    console.log("🎉 ALL PROCESS TESTS COMPLETED SUCCESSFULLY!");
    console.log("=".repeat(60));
    
    return deployment;

  } catch (error) {
    console.error("\n" + "=".repeat(60));
    console.error("💥 PROCESS TEST FAILED");
    console.error("=".repeat(60));
    console.error("Error:", error);
    process.exit(1);
  }
}

runProcessTest()

export { runProcessTest };