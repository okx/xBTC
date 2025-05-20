# OKX xBTC:

xBTC is a token implementation on the Sui blockchain that represents Bitcoin.

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

xBTC is built on Sui Move with the following technical specifications:

- **Token Symbol**: xBTC
- **Token Name**: OKX Wrapped BTC
- **Decimals**: 8 (same as Bitcoin)
- **Capabilities**:
  - `TreasuryCap`: Controls token supply (owned by minter)
  - `DenyCapV2`: Controls deny list operations (owned by denylister)
  - `XBTCReceiver`: Stores the designated receiver address for minting (shared object)

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

## Deployment

To deploy the xBTC token, navigate to the `scripts` directory and run the deployment script:

```bash
cd scripts
./deploy.sh
```

This script will handle the necessary steps to publish the smart contract to the Sui network.
Make sure you have the Sui CLI installed and configured correctly before running the script.

