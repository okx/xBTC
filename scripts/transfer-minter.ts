import hre from "hardhat";

const { ethers } = hre;

async function main() {
  console.log("Starting xBTC minter role transfer...");

  // Get the current minter account
  const [currentMinter] = await ethers.getSigners();
  console.log("Current minter account:", currentMinter.address);

  // Get balance
  const balance = await currentMinter.provider.getBalance(currentMinter.address);
  console.log("Account balance:", ethers.formatEther(balance), "ETH");

  // Contract address - you need to provide this from deployment
  const PROXY_ADDRESS = process.env.XBTC_PROXY_ADDRESS || "";
  const NEW_MINTER_ADDRESS = process.env.NEW_MINTER_ADDRESS || "";

  if (!PROXY_ADDRESS) {
    console.error("❌ XBTC_PROXY_ADDRESS not provided in environment variables");
    console.log("Please set XBTC_PROXY_ADDRESS=<proxy_address>");
    process.exit(1);
  }

  if (!NEW_MINTER_ADDRESS) {
    console.error("❌ NEW_MINTER_ADDRESS not provided in environment variables");
    console.log("Please set NEW_MINTER_ADDRESS=<new_minter_address>");
    process.exit(1);
  }

  // Validate new minter address
  if (!ethers.isAddress(NEW_MINTER_ADDRESS)) {
    console.error("❌ Invalid NEW_MINTER_ADDRESS format");
    process.exit(1);
  }

  console.log("Using xBTC contract at:", PROXY_ADDRESS);
  console.log("New minter address:", NEW_MINTER_ADDRESS);

  // Connect to the deployed xBTC contract
  const xbtcFactory = await ethers.getContractFactory("Token");
  const xBTC = xbtcFactory.attach(PROXY_ADDRESS);

  // Verify contract connection
  console.log("\n1. Verifying contract connection...");
  try {
    const name = await xBTC.name();
    const symbol = await xBTC.symbol();
    const version = await xBTC.version();

    console.log("✅ Contract connected successfully!");
    console.log("Token name:", name);
    console.log("Token symbol:", symbol);
    console.log("Contract version:", version);
  } catch (error) {
    console.error("❌ Failed to connect to contract:", error);
    process.exit(1);
  }

  // Check if current account has minter role
  console.log("\n2. Checking current minter permissions...");
  const MINTER_ROLE = await xBTC.MINTER_ROLE();
  const hasCurrentMinterRole = await xBTC.hasRole(MINTER_ROLE, currentMinter.address);

  if (!hasCurrentMinterRole) {
    console.error("❌ Current account does not have MINTER_ROLE");
    console.log("Only the current minter can transfer the minter role");
    process.exit(1);
  }
  console.log("✅ Current account has minter permissions");

  // Check if new minter already has the role
  const hasNewMinterRole = await xBTC.hasRole(MINTER_ROLE, NEW_MINTER_ADDRESS);
  if (hasNewMinterRole) {
    console.error("❌ New minter address already has MINTER_ROLE");
    process.exit(1);
  }

  // Check if new minter is the same as current minter
  if (NEW_MINTER_ADDRESS.toLowerCase() === currentMinter.address.toLowerCase()) {
    console.error("❌ New minter cannot be the same as current minter");
    process.exit(1);
  }

  console.log("✅ New minter address is valid and doesn't already have the role");

  // Display transfer summary
  console.log("\n3. Transfer Summary:");
  console.log("====================================");
  console.log("Current minter:", currentMinter.address);
  console.log("New minter:", NEW_MINTER_ADDRESS);
  console.log("Contract address:", PROXY_ADDRESS);
  console.log("====================================");

  // Confirm the transfer
  console.log("\n4. Transferring minter role...");

  try {
    // Transfer the minter role
    console.log("Sending transfer transaction...");
    const transferTx = await xBTC.transferMinter(NEW_MINTER_ADDRESS);
    console.log("Transaction hash:", transferTx.hash);

    // Wait for confirmation
    const receipt = await transferTx.wait();
    console.log("✅ Transfer transaction confirmed in block:", receipt?.blockNumber);

    // Verify the transfer
    const currentMinterHasRole = await xBTC.hasRole(MINTER_ROLE, currentMinter.address);
    const newMinterHasRole = await xBTC.hasRole(MINTER_ROLE, NEW_MINTER_ADDRESS);

    console.log("\n5. Transfer Verification:");
    console.log("====================================");
    console.log("Current minter still has role:", currentMinterHasRole);
    console.log("New minter now has role:", newMinterHasRole);
    console.log("Transaction hash:", transferTx.hash);
    console.log("====================================");

    if (!currentMinterHasRole && newMinterHasRole) {
      console.log("✅ Minter role transferred successfully!");
    } else {
      console.error("❌ Role transfer verification failed");
      process.exit(1);
    }

  } catch (error: any) {
    console.error("❌ Transfer transaction failed:", error);

    // Try to parse the revert reason
    if (error.reason) {
      console.log("Revert reason:", error.reason);
    }
    if (error.data) {
      try {
        const decodedError = xbtcFactory.interface.parseError(error.data);
        console.log("Decoded error:", decodedError?.name, decodedError?.args);
      } catch {
        console.log("Could not decode error data");
      }
    }

    process.exit(1);
  }
}

// Execute the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });