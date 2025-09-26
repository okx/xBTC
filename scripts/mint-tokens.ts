import hre from "hardhat";
import { DEPLOYMENT_CONFIG } from "./deployment-config.ts";

const { ethers } = hre;

async function main() {
  console.log("Starting xBTC token minting...");

  // Get the deployer/minter account
  const [deployer] = await ethers.getSigners();
  console.log("Minting with account:", deployer.address);

  // Get balance
  const balance = await deployer.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "ETH");

  // Contract address - you need to provide this from deployment
  const PROXY_ADDRESS = process.env.XBTC_PROXY_ADDRESS || "";

  if (!PROXY_ADDRESS) {
    console.error("❌ XBTC_PROXY_ADDRESS not provided in environment variables");
    console.log("Please set XBTC_PROXY_ADDRESS=<proxy_address> or provide it directly in the script");
    process.exit(1);
  }

  console.log("Using xBTC contract at:", PROXY_ADDRESS);

  // Connect to the deployed xBTC contract
  const xbtcFactory = await ethers.getContractFactory("xbtc");
  const xBTC = xbtcFactory.attach(PROXY_ADDRESS);

  // Verify contract connection
  console.log("\n1. Verifying contract connection...");
  try {
    const name = await xBTC.name();
    const symbol = await xBTC.symbol();
    const decimals = await xBTC.decimals();
    const maxSupply = await xBTC.MAX_SUPPLY();
    const currentSupply = await xBTC.totalSupply();

    console.log("✅ Contract connected successfully!");
    console.log("Token name:", name);
    console.log("Token symbol:", symbol);
    console.log("Decimals:", decimals);
    console.log("Max supply:", ethers.formatUnits(maxSupply, 8), "tokens");
    console.log("Current supply:", ethers.formatUnits(currentSupply, 8), "tokens");
  } catch (error) {
    console.error("❌ Failed to connect to contract:", error);
    process.exit(1);
  }

  // Check if deployer has minter role
  console.log("\n2. Checking minter permissions...");
  const MINTER_ROLE = await xBTC.MINTER_ROLE();
  const hasMinterRole = await xBTC.hasRole(MINTER_ROLE, deployer.address);

  if (!hasMinterRole) {
    console.error("❌ Account does not have MINTER_ROLE");
    console.log("Minter role required to mint tokens");
    process.exit(1);
  }
  console.log("✅ Account has minter permissions");

  // Get authorized receiver
  const receiver = await xBTC.getReceiver();
  console.log("Authorized receiver:", receiver);

  // Check if contract is paused
  const isPaused = await xBTC.paused();
  if (isPaused) {
    console.error("❌ Contract is paused, cannot mint tokens");
    process.exit(1);
  }
  console.log("✅ Contract is not paused");

  // Define mint amount (default to 1000 tokens if not provided)
  const MINT_AMOUNT = process.env.MINT_AMOUNT || "1000";
  const mintAmountWei = ethers.parseUnits(MINT_AMOUNT, 8); // 8 decimals for xBTC

  console.log("\n3. Minting tokens...");
  console.log("Amount to mint:", MINT_AMOUNT, "tokens");
  console.log("Amount in wei (8 decimals):", mintAmountWei.toString());
  console.log("Recipient:", receiver);

  // Check if minting would exceed max supply
  const currentSupply = await xBTC.totalSupply();
  const maxSupply = await xBTC.MAX_SUPPLY();

  if (currentSupply + mintAmountWei > maxSupply) {
    console.error("❌ Minting would exceed maximum supply");
    console.log("Current supply:", ethers.formatUnits(currentSupply, 8));
    console.log("Requested mint:", MINT_AMOUNT);
    console.log("Max supply:", ethers.formatUnits(maxSupply, 8));
    process.exit(1);
  }

  try {
    // Mint the tokens
    console.log("Sending mint transaction...");
    const mintTx = await xBTC.mint(receiver, mintAmountWei);
    console.log("Transaction hash:", mintTx.hash);

    // Wait for confirmation
    const receipt = await mintTx.wait();
    console.log("✅ Mint transaction confirmed in block:", receipt?.blockNumber);

    // Verify the mint
    const newSupply = await xBTC.totalSupply();
    const receiverBalance = await xBTC.balanceOf(receiver);

    console.log("\n4. Mint Summary:");
    console.log("====================================");
    console.log("Minted amount:", MINT_AMOUNT, "tokens");
    console.log("New total supply:", ethers.formatUnits(newSupply, 8), "tokens");
    console.log("Receiver balance:", ethers.formatUnits(receiverBalance, 8), "tokens");
    console.log("Transaction hash:", mintTx.hash);
    console.log("====================================");
    console.log("✅ Tokens minted successfully!");

  } catch (error: any) {
    console.error("❌ Mint transaction failed:", error);

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