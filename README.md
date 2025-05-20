# OKX xBTC:

xBTC is a token implementation on the Aptos blockchain that represents Bitcoin using the Fungible Asset standard.

## Features

xBTC token has the following features and functionalities:

1. **Basic Information**:
   - Symbol: xBTC
   - Name: OKX Wrapped BTC
   - Decimals: 8
   - Compatible with Aptos Fungible Asset standard

2. **Management Functions**:
   - Mint/Burn: Supports minting by admin and burning by designated users
   - Freeze/Unfreeze: Can freeze specific addresses, preventing transfers
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
        ├── xbtc.move      # xBTC token main contract
        └── xbtc_tests.move # xBTC contract tests
```

## Usage Guide

### Compile
```bash
aptos move compile --named-addresses okx_xbtc=<address>
```
Example:
```bash
aptos move compile --named-addresses okx_xbtc=0x13526c24d1785380dacb52ae6c242475e08ad7b5a8ecf324b2895e6790456732
```

### Deploy
```bash
aptos move deploy-object --address-name okx_xbtc
```