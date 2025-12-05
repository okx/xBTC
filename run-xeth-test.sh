#!/bin/bash

# Script to deploy and test xETH token on local Anvil testnet
# This script will:
# 1. Start a local Anvil testnet
# 2. Deploy the xETH contracts
# 3. Run comprehensive tests on all functions

set -e

echo "==================================="
echo "xETH Deployment and Testing Script"
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
echo -e "${BLUE}Setting test environment variables...${NC}"
# Two addresses strategy with both having private keys:
# - ADMIN_PK: Deployer private key (gets all roles, sends most transactions)
# - TEST_ACCOUNT_PK: Test user private key (for testing transfers, approvals, etc.)
export ADMIN_PK=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export TEST_ACCOUNT_PK=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
export RPC_URL=http://127.0.0.1:8545

# Derive addresses for display
ADMIN=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
TEST_ACCOUNT=0x70997970C51812dc3A010C7d01b50e0d17dc79C8

echo "ADMIN (Anvil #0): $ADMIN"
echo "TEST_ACCOUNT (Anvil #1): $TEST_ACCOUNT"

echo ""
echo -e "${BLUE}Running xETH test script...${NC}"
forge script scripts/Test.xETH.testnet.s.sol:TestXETH \
    --rpc-url $RPC_URL \
    --broadcast

echo ""
echo -e "${GREEN}==================================="
echo "Test execution completed!"
echo "===================================${NC}"

# Cleanup function
cleanup() {
    if [ ! -z "$ANVIL_PID" ]; then
        echo ""
        echo -e "${YELLOW}Stopping Anvil (PID: $ANVIL_PID)...${NC}"
        kill $ANVIL_PID 2>/dev/null || true
    fi
}

# Register cleanup function
# trap cleanup EXIT

echo ""
echo -e "${YELLOW}Note: Anvil is still running. Stop it manually if needed with: pkill anvil${NC}"

