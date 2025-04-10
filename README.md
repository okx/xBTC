# xBTC: Regulated Bitcoin on Sui

xBTC is a regulated token implementation on the Sui blockchain that represents Bitcoin. It provides enhanced compliance features while maintaining the core functionality expected of a fungible token.

## Features

- **Regulated minting**: Only the minter can mint tokens, and only to the designated receiver address
- **Initial zero address receiver**: The system initializes with a zero address receiver that must be set before minting
- **Admin-only burning**: Only the minter (admin) can burn tokens
- **Regulatory compliance**:
  - Deny list (blacklist) functionality to restrict certain addresses
  - Global pause capability for emergency situations
- **Role-based governance**: Different capabilities for minting and deny listing
- **Access control**: Separate roles for minting and compliance management

## Technical Details

xBTC is built on Sui Move with the following technical specifications:

- **Token Symbol**: xBTC
- **Token Name**: Regulated Bitcoin
- **Decimals**: 8 (same as Bitcoin)
- **Capabilities**:
  - `TreasuryCap`: Controls token supply (owned by minter)
  - `DenyCapV2`: Controls deny list operations (owned by denylister)
  - `XBTCReceiver`: Stores the designated receiver address for minting (owned by minter)

## Project Structure

```
xbtc/
├── Move.toml          # Package definition
├── sources/
│   └── xbtc.move      # Token implementation
├── tests/
│   ├── shell_tests/   # Shell-based tests
│   └── typescript_tests/ # TypeScript tests
└── scripts/           # Deployment and utility scripts
```

## Getting Started

### Prerequisites

- [Sui CLI](https://docs.sui.io/build/install)
- [Node.js](https://nodejs.org/) (for TypeScript scripts)
- [TypeScript](https://www.typescriptlang.org/)

### Setup

1. Clone the repository:

```bash
git clone <repository-url>
cd xbtc-sui
```

2. Install dependencies:

```bash
# Install Sui CLI (if not already installed)
cargo install --locked --git https://github.com/MystenLabs/sui.git --branch main sui

# Install Node.js dependencies for scripts
cd xbtc/scripts
npm install
```

3. Build the Move package:

```bash
cd ../
sui move build
```

4. Run the tests:

```bash
# Run shell-based tests
./tests/test_xbtc.sh

# Or run TypeScript tests
cd scripts
ts-node test_xbtc.ts
```

### Deployment

To deploy the xBTC token to the Sui network:

```bash
# Deploy and run tests
./tests/test_xbtc.sh
```

The deployment script will:
1. Build the Move package
2. Publish it to the specified network
3. Save deployment information to a configuration file

## Security and Control

The xBTC token implements several security features:

1. **Zero address initialization**: Receiver starts at zero address requiring explicit setting before minting
2. **Receiver validation**: Minting only allowed to the address set in XBTCReceiver
3. **Role separation**: Different capabilities for token supply and deny listing
4. **Emergency controls**: Global pause functionality for crisis management

## License

Apache License 2.0 