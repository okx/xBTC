import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { PREDETERMINED_ADDRESSES, TOKEN_CONFIG } from "../../scripts/deployment-config";

export default buildModule("xBTCModule", (m) => {
  // Deploy the implementation contract
  const implementation = m.contract("xbtc");

  // Prepare initialization data
  const initData = m.encodeFunctionCall(implementation, "initialize", [
    TOKEN_CONFIG.NAME,
    TOKEN_CONFIG.SYMBOL,
    PREDETERMINED_ADDRESSES.ADMIN,
    PREDETERMINED_ADDRESSES.MINTER,
    PREDETERMINED_ADDRESSES.TREASURY, // Initial receiver
  ]);

  // Deploy the proxy
  const proxy = m.contract("xbtcProxy", [
    implementation, 
    PREDETERMINED_ADDRESSES.ADMIN, // proxy admin
    initData
  ]);

  // Create a readable contract instance pointing to the proxy
  const xBTC = m.contractAt("xbtc", proxy);

  return { 
    implementation,
    proxy,
    xBTC,
    config: {
      implementationAddress: implementation,
      proxyAddress: proxy,
      adminAddress: PREDETERMINED_ADDRESSES.ADMIN,
      minterAddress: PREDETERMINED_ADDRESSES.MINTER,
      treasuryAddress: PREDETERMINED_ADDRESSES.TREASURY,
    }
  };
});