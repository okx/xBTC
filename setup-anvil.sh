#!/bin/bash

# Prepare local Anvil testnet
# This script will:
# 1. Start a local Anvil testnet
# 2. Export test environment variables

set -e

echo "==================================="
echo "Prepare local Anvil testnet"
echo "==================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if anvil is running
if lsof -Pi :8545 -sTCP:LISTEN -t >/dev/null ; then
    echo -e "${YELLOW}Anvil is already running on port 8545${NC}"
    echo "Using existing Anvil instance..."
else
    echo -e "${BLUE}Starting Anvil testnet...${NC}"
    anvil > /dev/null 2>&1 &
    ANVIL_PID=$!
    echo "Anvil started with PID: $ANVIL_PID"
    sleep 2
fi

echo ""
echo -e "${BLUE}Copy and paste the following environment variables to your terminal${NC}"
# Two addresses strategy with both having private keys:
# - ADMIN_PK: Deployer private key (gets all roles, sends most transactions)
# - TEST_ACCOUNT_PK: Test user private key (for testing transfers, approvals, etc.)
ADMIN_PK=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
TEST_ACCOUNT_PK=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
RPC_URL=http://127.0.0.1:8545
# Derive addresses for display
ADMIN=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
TEST_ACCOUNT=0x70997970C51812dc3A010C7d01b50e0d17dc79C8

echo "export ADMIN_PK=$ADMIN_PK"
echo "export TEST_ACCOUNT_PK=$TEST_ACCOUNT_PK"
echo "export RPC_URL=$RPC_URL"

