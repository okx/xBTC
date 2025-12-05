export const DEPLOYMENT_CONFIG = {
  // Using CREATE2 salt to ensure same addresses across chains
  IMPLEMENTATION_SALT: process.env.IMPLEMENTATION_SALT,
  PROXY_SALT: process.env.PROXY_SALT,
  
  // Role addresses from environment variables
  ADMIN: process.env.ADMIN || "",
  MINTER: process.env.MINTER || "",
  TREASURY: process.env.TREASURY || "",
};

export const TOKEN_CONFIG = {
  NAME: "OKX Wrapped BTC",
  SYMBOL: "xBTC",
  DECIMALS: 8,
  MAX_SUPPLY: BigInt("21000000") * BigInt(10) ** BigInt(8), // 21M xBTC
};