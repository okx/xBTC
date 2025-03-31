# XBTC - Wrapped Bitcoin Token Contract (Aptos)

XBTC is a Wrapped Bitcoin implementation based on the Aptos blockchain, built using the Fungible Asset standard.

## Features

XBTC token has the following features and functionalities:

1. **Basic Information**:
   - Symbol: XBTC
   - Name: Wrapped Bitcoin
   - Decimals: 8
   - Compatible with Aptos Fungible Asset standard

2. **Management Functions**:
   - Mint/Burn: Supports minting by admin and burning by designated users
   - Freeze/Unfreeze: Can freeze specific addresses, preventing transfers
   - Blacklist: Can add addresses to a blacklist, completely restricting operations
   - Global Pause: Can pause all transfer operations as an emergency mechanism

3. **Security Features**:
   - Separation of Privileges: Different management functions can be assigned to different addresses
   - Event Publication: All key operations publish events
   - Non-upgradable: Contract logic cannot be changed, ensuring security

## Project Structure

```
xbtc-aptos/
├── scripts/               # Scripts for deployment and operations
└── sources/               # Move contract source code
    └── xbtc/
        ├── xbtc.move      # XBTC token main contract
        └── xbtc_tests.move # XBTC contract tests
```

## Usage Guide

### compile
```bash
aptos move compile --named-addresses okx_xbtc=<address>
```
Example:
```bash
aptos move compile --named-addresses okx_xbtc=0x13526c24d1785380dacb52ae6c242475e08ad7b5a8ecf324b2895e6790456732
```

### deploy
```bash
aptos move deploy-object --address-name okx_xbtc
```