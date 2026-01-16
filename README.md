# OKX xAsset EVM

xAssets are centralized issued ERC-20 tokens backed by OKX, containing 2 categories:
1. Wrapped Tokens (1:1 Backed). Direct on-chain representations of underlying assets with guaranteed 1:1 backing by OKX reserves. Example: xBTC, xETH, xSOL.
2. Liquid Staking Tokens (Yield-Bearing). Tokenized staking positions that accrue staking rewards while remaining fully liquid and transferable. Example: xBETH, xOKSOL.

## Supported Tokens

### Wrapped Tokens
| Token | Deployed Address |
|-------|------------------|
| xBTC  | https://www.oklink.com/zh-hans/x-layer/token/0xb7C00000bcDEeF966b20B3D884B98E64d2b06b4f |
| xETH  | |
| xSOL  | |

### Staked Tokens
| Token   | Deployed Address |
|---------|------------------|
| xBETH   | |
| xOKSOL  | |

## Architecture

```mermaid
classDiagram
    Token <|-- xBTC
    Token <|-- xETH
    Token <|-- xSOL
    Token <|-- StakedTokenV1
    StakedTokenV1 <|-- xBETH
    StakedTokenV1 <|-- xOKSOL
    RateLimit <|-- ExchangeRateUpdater
    ExchangeRateUpdater ..> StakedTokenV1 : updates rate

    class Token {
        +MINTER_ROLE
        +DENY_LISTER_ROLE
        +MAX_SUPPLY
        +denyList
        +authorizedReceiver
        +mint()
        +burn()
        +pause()
        +unpause()
        +addToDenyList()
        +removeFromDenyList()
    }

    class StakedTokenV1 {
        +oracle
        +exchangeRate
        +updateOracle()
        +updateExchangeRate()
    }

    class RateLimit {
        +allowances
        +maxAllowance
        +replenishRate
        +addCaller()
        +removeCaller()
    }

    class ExchangeRateUpdater {
        +tokenContract
        +updateExchangeRate()
    }

    class xBTC {
        +decimals() 8
    }

    class xETH {
        +decimals() 18
    }

    class xSOL {
        +decimals() 9
    }

    class xBETH {
        +decimals() 18
    }

    class xOKSOL {
        +decimals() 9
    }
```

## Features

### Base Token Features
- **Regulated minting**: Only the minter can mint tokens to the designated receiver address
- **Admin-only burning**: Only the minter can burn tokens
- **Deny list (blacklist)**: Functionality to restrict certain addresses
- **Global pause**: Capability for emergency situations
- **Role-based governance**: Separate roles for minting and compliance management
- **Upgradeable**: Transparent proxy pattern for seamless contract upgrades
- **ERC-2612 Permit**: Gasless approvals via EIP-712 signatures

### Staked Token Features (xBETH, xOKSOL)
All base features plus:
- **Exchange rate oracle**: Dynamic rate updates for staked asset value
- **Oracle management**: Admin-controlled oracle address updates
- **Rate-limited exchange rate updates**: `ExchangeRateUpdater` contract limits the magnitude of exchange rate changes to prevent large unexpected fluctuations

## Technical Details

Built on OpenZeppelin's upgradeable contracts with:
- **Role-based Access Control**:
  - `MINTER_ROLE`: Controls token supply (mint/burn)
  - `DENY_LISTER_ROLE`: Controls deny list and pause operations
  - `DEFAULT_ADMIN_ROLE`: Controls role management and oracle (for staked tokens)
    - **Upgradeable Architecture**: Transparent proxy pattern for seamless contract upgrades
- **EIP-712 typed data signing**: For meta-transactions and permit

## Project Structure

```
├── contracts/                   # production Solidity contracts
│   ├── xToken.sol
│   ├── xbtc.sol
│   ├── xbtcProxy.sol
│   ├── StakedTokenV1.sol
│   ├── ExchangeRateUpdater.sol
│   ├── ExchangeRateUtil.sol
│   ├── RateLimit.sol
│   ├── Proxy.sol
│   └── verify/                  # explorer verification sources (xETH/xSOL/xBETH/xOKSOL)
├── scripts/                     # Hardhat TS scripts + Foundry scripts/utils (.s.sol/.sol)
│   ├── deploy.ts
│   ├── deployment-config.ts
│   └── Deploy.*.s.sol
├── test/                        # Hardhat (.ts) + Foundry (.t.sol) tests
│   ├── xBTC.*.test.ts
│   └── *.t.sol
├── hardhat.config.ts
└── foundry.toml
```

## Development

### Prerequisites
- Node.js >= 18
- Foundry (for Solidity tests)

### Installation
```bash
yarn
```

### Testing

#### Foundry Tests
```bash
# Run all Foundry tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test file
forge test --match-path test/Token.t.sol
```

#### Hardhat Tests (xBTC only)
```bash
# Run all Hardhat tests
npx hardhat test

# Run specific test
npx hardhat test test/xBTC.comprehensive.test.ts
```

### Coverage
```bash
# Foundry coverage
forge coverage

# Hardhat coverage
npx hardhat coverage
```

## Deployment

### xBTC Hardhat Deployment

To deploy the xBTC token:

```bash
# Compile contracts
npx hardhat compile

# Deploy to local network
npx hardhat run scripts/deploy.ts

# Deploy to Sepolia testnet
npx hardhat run scripts/deploy.ts --network sepolia
```

Make sure you have Hardhat installed and configured correctly before running the deployment script.

## Audits

The contracts have been audited by the following auditors:
- [Zellic](./audits/xAsset%20-%20Zellic%20Audit%20Report.pdf)
- [OKX](./audits/OKX%20xAsset%20Audit%20Report.pdf)

## Credits

The staked token implementation (`StakedTokenV1.sol`) and exchange rate contracts (`ExchangeRateUpdater.sol`, `ExchangeRateUtil.sol`, `RateLimit.sol`) are derived from Coinbase's [wrapped-tokens-os](https://github.com/coinbase/wrapped-tokens-os) project (cbETH).

## License

MIT
