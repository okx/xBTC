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
│   ├── test_xbtc.sh   # Shell-based tests
│   └── test_xbtc.ts   # TypeScript tests
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

## Key Operations

### Minting Workflow

1. **Set receiver address**: The minter must first set a valid receiver address
   ```bash
   sui client call --package $PACKAGE_ID --module xbtc --function set_receiver \
     --args $TREASURY_CAP_ID $RECEIVER_ID $RECIPIENT_ADDRESS \
     --gas-budget 10000000
   ```

2. **Mint tokens**: Tokens can only be minted to the designated receiver address
   ```bash
   sui client call --package $PACKAGE_ID --module xbtc --function mint \
     --args $TREASURY_CAP_ID $RECEIVER_ID $AMOUNT $RECIPIENT_ADDRESS \
     --gas-budget 10000000
   ```

### Compliance Operations

- **Add to deny list**: Prevent specific addresses from transferring tokens
   ```bash
   sui client call --package $PACKAGE_ID --module xbtc --function add_to_deny_list \
     --args $DENY_LIST_ID $DENY_CAP_ID $TARGET_ADDRESS \
     --gas-budget 10000000
   ```

- **Global pause**: Temporarily prevent all token transfers
   ```bash
   sui client call --package $PACKAGE_ID --module xbtc --function set_pause \
     --args $DENY_LIST_ID $DENY_CAP_ID true \
     --gas-budget 10000000
   ```

### Admin Operations

- **Burn tokens**: Only the minter can burn tokens
   ```bash
   sui client call --package $PACKAGE_ID --module xbtc --function burn \
     --args $TREASURY_CAP_ID $COIN_ID \
     --gas-budget 10000000
   ```

- **Transfer minter role**: Transfer minting capability to a new address
   ```bash
   sui client call --package $PACKAGE_ID --module xbtc --function transfer_minter_role \
     --args $TREASURY_CAP_ID $RECEIVER_ID $NEW_MINTER_ADDRESS \
     --gas-budget 10000000
   ```

- **Transfer denylister role**: Transfer deny list capability to a new address
   ```bash
   sui client call --package $PACKAGE_ID --module xbtc --function transfer_denylister_role \
     --args $DENY_CAP_ID $NEW_DENYLISTER_ADDRESS \
     --gas-budget 10000000
   ```

## Security and Control

The xBTC token implements several security features:

1. **Zero address initialization**: Receiver starts at zero address requiring explicit setting before minting
2. **Receiver validation**: Minting only allowed to the address set in XBTCReceiver
3. **Role separation**: Different capabilities for token supply and deny listing
4. **Emergency controls**: Global pause functionality for crisis management

## License

Apache License 2.0 