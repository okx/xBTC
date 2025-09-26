# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Hardhat 3 Beta project that implements xBTC, an upgradeable ERC-20 token contract for cross-chain Bitcoin representation. The project uses TypeScript, Mocha for testing, and ethers.js for Ethereum interactions.

## Core Architecture

- **Primary Contract**: `contracts/xbtc_evm.sol` - xBTCImplementation contract that implements an upgradeable ERC-20 token with:
  - 8 decimal places (matching Bitcoin)
  - 21 million max supply
  - Role-based access control (ADMIN_ROLE, MINTER_ROLE)
  - Address blocking functionality for compliance
  - EIP-3009 transfer authorization
  - ERC-20 Permit support
  - Pausable functionality

- **Test Structure**: Comprehensive TypeScript test suite with 45+ tests covering all functionality
- **Network Configuration**: Supports local simulation of Ethereum mainnet and Optimism, plus Sepolia testnet deployment

## Development Commands

### Testing
```bash
npx hardhat test                    # Run all tests
npx hardhat test mocha             # Run TypeScript/Mocha tests only
npx hardhat test solidity         # Run Solidity tests only
```

### Building and Compilation
```bash
npx hardhat build                  # Compile contracts
npx hardhat compile               # Alias for build
npx hardhat clean                 # Clear cache and artifacts
```

### Deployment
```bash
# Local deployment
npx hardhat ignition deploy ignition/modules/xBTC.ts

# Sepolia deployment (requires SEPOLIA_PRIVATE_KEY config)
npx hardhat keystore set SEPOLIA_PRIVATE_KEY
npx hardhat ignition deploy --network sepolia ignition/modules/xBTC.ts
```

### Development Tools
```bash
npx hardhat console               # Open Hardhat console
npx hardhat node                 # Start local JSON-RPC server
npx hardhat run scripts/send-op-tx.ts  # Run example OP chain transaction

## Testing Commands

### Unit and Integration Tests
```bash
npx hardhat test                           # Run all tests
npx hardhat test test/xBTC.proxy.test.ts   # Run basic proxy tests (8 tests)
npx hardhat test test/xBTC.comprehensive.test.ts  # Run comprehensive tests (32 tests)
npx hardhat test test/xBTC.deployment.test.ts     # Run end-to-end deployment test (5 tests)
```
```

## Contract Architecture Details

### xBTC Implementation Contract
The xbtc contract uses OpenZeppelin's upgradeable patterns:
- Proxy-safe initialization instead of constructor
- Access control for privileged operations
- Comprehensive event emission for all state changes
- EIP-712 typed data signing for meta-transactions

Key security features:
- Address blocking for compliance requirements
- Role separation between admin and minter functions
- Maximum supply enforcement
- Transfer validation in `_update` override

### xbtcProxy Contract
Optimized TransparentUpgradeableProxy implementation:
- Minimal attack surface with no additional functions
- Gas-optimized for multi-chain deployment
- Comprehensive NatSpec documentation
- Follows transparent proxy pattern for admin separation
- Secure upgrade mechanism via ProxyAdmin contract

## Network Configuration

- `hardhatMainnet`: Local L1 simulation
- `hardhatOp`: Local Optimism simulation  
- `sepolia`: Testnet deployment (requires configuration variables)

Configuration variables are managed through Hardhat 3's config system or environment variables.