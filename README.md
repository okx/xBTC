# OKX xBTC:

xBTC is a token implementation on the EVM blockchain that represents Bitcoin.

## Features

- **Regulated minting**: Only the minter can mint tokens, and only to the designated receiver address
- **Initial zero address receiver**: The system initializes with a zero address receiver that must be set before minting
- **Admin-only burning**: Only the minter (admin) can burn tokens
- **Regulatory**:
    - Deny list (blacklist) functionality to restrict certain addresses
    - Global pause capability for emergency situations
- **Role-based governance**: Different capabilities for minting and deny listing
- **Access control**: Separate roles for minting and compliance management

## Technical Details

xBTC is built on EVM with the following technical specifications:

- **Token Symbol**: xBTC
- **Token Name**: OKX Wrapped BTC
- **Decimals**: 8 (same as Bitcoin)
- **Capabilities**:
    - `MINTER_ROLE`: Controls token supply (owned by minter)
    - `DENY_LISTER_ROLE`: Controls deny list operations (owned by denylister)
    - **Upgradeable Architecture**: Transparent proxy pattern for seamless contract upgrades

## Test Coverage

Our smart contracts achieve **enterprise-grade test coverage** with comprehensive testing across all features:

```
File            |  % Stmts | % Branch |  % Funcs |  % Lines |
----------------|----------|----------|----------|----------|
contracts/      |      100 |      100 |      100 |      100 |
 xbtc.sol       |      100 |      100 |      100 |      100 |
 xbtcProxy.sol  |      100 |      100 |      100 |      100 |
----------------|----------|----------|----------|----------|
All files       |      100 |      100 |      100 |      100 |
```

**Test Statistics:**
- ✅ **126 Tests Passing** (0 failures)
- ✅ **100% Statement Coverage**
- ✅ **100% Function Coverage**
- ✅ **100% Line Coverage**
- ✅ **100% Branch Coverage**

**Test Categories:**
- **Core Functionality**: Minting, burning, transfers, approvals
- **Access Control**: Role management, permission verification
- **Security Features**: Pause/unpause, address blocking
- **Advanced Features**: EIP-712 signatures, meta-transactions
- **Edge Cases**: Zero amounts, max supply, blocked addresses
- **Integration Tests**: End-to-end deployment and operations

## Project Structure

```
xbtc_evm/
├── hardhat.config.ts    # Hardhat configuration
├── contracts/
│   ├── xbtc_evm.sol     # Token implementation
│   └── xbtcProxy.sol    # Transparent upgradeable proxy
├── test/
│   ├── xBTC.proxy.test.ts        # Proxy tests
│   ├── xBTC.comprehensive.test.ts # Comprehensive functionality tests
│   └── xBTC.e2e.test.ts         # End-to-end deployment tests
└── scripts/             # Deployment and utility scripts
    └── deploy.ts        # Main deployment script
```

## Deployment

To deploy the xBTC token:

```bash
# Install dependencies
npm install

# Compile contracts
npx hardhat compile

# Run tests
npx hardhat test

# Deploy to local network
npx hardhat run scripts/deploy.ts

# Deploy to Sepolia testnet
npx hardhat run scripts/deploy.ts --network sepolia
```

Make sure you have Hardhat installed and configured correctly before running the deployment script.