import hre from "hardhat";
import { DEPLOYMENT_CONFIG, TOKEN_CONFIG } from "./deployment-config.ts";

const { ethers } = hre;

async function main() {
  console.log("Starting xBTC deployment...");
  const SAFE_CREATE2_FACTORY = "0x0000000000ffe8b47b3e2130213b802212439497";
  const SALT_IMPLEMENTATION = DEPLOYMENT_CONFIG.IMPLEMENTATION_SALT;
  const SALT_PROXY = DEPLOYMENT_CONFIG.PROXY_SALT;

  // Get the deployer account
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);
  const balance = await deployer.provider.getBalance(deployer.address);
  console.log("Account balance:", ethers.formatEther(balance), "ETH");

  // Prepare contract factories and calculate init codes
  console.log("\nPreparing contract factories and init codes...");
  const xbtcFactory = await ethers.getContractFactory("xbtc");
  const xbtcProxyFactory = await ethers.getContractFactory("xbtcProxy");
  
  console.log("xbtc init_code:", xbtcFactory.bytecode);
  console.log("xbtc init_code_hash:", ethers.keccak256(xbtcFactory.bytecode));

  const deployedAddress_impl = ethers.getCreate2Address(
    SAFE_CREATE2_FACTORY,
    SALT_IMPLEMENTATION,
    ethers.keccak256(xbtcFactory.bytecode)
  );
  console.log("Pre-calculated implementation address:", deployedAddress_impl);

  // Prepare initialization data
  const initData = xbtcFactory.interface.encodeFunctionData("initialize", [
    TOKEN_CONFIG.NAME,
    TOKEN_CONFIG.SYMBOL,
    DEPLOYMENT_CONFIG.ADMIN,
    DEPLOYMENT_CONFIG.MINTER,
    DEPLOYMENT_CONFIG.TREASURY, // Initial receiver
  ]);

  console.log("init data", initData);

  // Encode constructor parameters for proxy deployment
  const proxyInitCode = ethers.concat([
    xbtcProxyFactory.bytecode,
    ethers.AbiCoder.defaultAbiCoder().encode(
      ["address", "address", "bytes"],
      [deployedAddress_impl, DEPLOYMENT_CONFIG.ADMIN, initData]
    )
  ]);
  
  console.log("xbtcProxy init_code with constructor params:", proxyInitCode);
  console.log("xbtcProxy init_code_hash:", ethers.keccak256(proxyInitCode));

  // Calculate proxy address in advance
  const deployedAddress_proxy = ethers.getCreate2Address(
    SAFE_CREATE2_FACTORY,
    SALT_PROXY,
    ethers.keccak256(proxyInitCode)
  );
  console.log("Pre-calculated proxy address:", deployedAddress_proxy);

  // Deploy the implementation contract
  console.log("\n1. Deploying xbtc implementation...");

  const factory = await ethers.getContractAt(
        [
            "function safeCreate2(bytes32 salt, bytes calldata initializationCode) external payable"
        ],
        SAFE_CREATE2_FACTORY
    );
    console.log("Salt:", SALT_IMPLEMENTATION);

    const tx_impl = await factory.safeCreate2(SALT_IMPLEMENTATION, xbtcFactory.bytecode);
    console.log("Transaction hash:", tx_impl.hash);

    const receipt_impl = await tx_impl.wait();
    console.log("Transaction confirmed in block:", receipt_impl?.blockNumber);
    console.log("Deployed contract address:", deployedAddress_impl);

  // Deploy the proxy
  console.log("\n2. Deploying xbtcProxy...");

  const tx_proxy = await factory.safeCreate2(SALT_PROXY, proxyInitCode);
  console.log("Transaction hash:", tx_proxy.hash);

  const receipt = await tx_proxy.wait();
  console.log("Transaction confirmed in block:", receipt?.blockNumber);
  console.log("Deployed contract address:", deployedAddress_proxy);

  // Create a contract instance pointing to the proxy
  const xBTC = xbtcFactory.attach(deployedAddress_proxy);

  console.log("\n3. Deployment Summary:");
  console.log("====================================");
  console.log("Implementation Address:", deployedAddress_impl);
  console.log("Proxy Address:", deployedAddress_proxy);
  console.log("Admin Address:", DEPLOYMENT_CONFIG.ADMIN);
  console.log("Minter Address:", DEPLOYMENT_CONFIG.MINTER);
  console.log("Treasury Address:", DEPLOYMENT_CONFIG.TREASURY);
  console.log("====================================");

  // Verify the deployment
  console.log("\n4. Verifying deployment...");
  try {
    const name = await xBTC.name();
    const symbol = await xBTC.symbol();
    const receiver = await xBTC.getReceiver();
    console.log("Token name:", name);
    console.log("Token symbol:", symbol);
    console.log("Authorized receiver:", receiver);
    console.log("✅ Deployment verified successfully!");
  } catch (error) {
    console.error("❌ Deployment verification failed:", error);
  }

  return {
    implementation: deployedAddress_impl,
    proxy: deployedAddress_proxy,
    xBTC: deployedAddress_proxy, // The proxy address is the main contract address
    config: {
      implementationAddress: deployedAddress_impl,
      proxyAddress: deployedAddress_proxy,
      adminAddress: DEPLOYMENT_CONFIG.ADMIN,
      minterAddress: DEPLOYMENT_CONFIG.MINTER,
      treasuryAddress: DEPLOYMENT_CONFIG.TREASURY,
    }
  };
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
