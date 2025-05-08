#!/bin/bash

# Load environment variables from .env file
if [ -f ".env" ]; then
  echo "Loading environment variables from .env"
  set -o allexport
  source .env
  set +o allexport
elif [ -f "../.env" ]; then
  echo "Loading environment variables from ../.env"
  set -o allexport
  source ../.env
  set +o allexport
else
  echo "Error: .env file not found in current or parent directory"
  exit 1
fi

# Check if required environment variables are set
if [ -z "$OWNER_ADDRESS" ] || [ -z "$ADMIN_ADDRESS" ] || [ -z "$TREASURY_CAP_ID" ] || [ -z "$DENY_LIST_CAP_ID" ] || [ -z "$UPGRADE_CAP_ID" ]; then
  echo "Error: Missing required environment variables. Please ensure your .env file contains:"
  echo "OWNER_ADDRESS: Address to transfer treasury cap to"
  echo "ADMIN_ADDRESS: Address to transfer deny list cap to"
  echo "TREASURY_CAP_ID: Object ID of treasury cap"
  echo "DENY_LIST_CAP_ID: Object ID of deny cap"
  echo "UPGRADE_CAP_ID: Object ID of upgrade cap"
  exit 1
fi

# Build the package
echo "Transferring Treasury Cap..."
echo "Target address: $OWNER_ADDRESS"
echo "Treasury Cap ID: $TREASURY_CAP_ID"
sui client transfer --to $OWNER_ADDRESS --object-id $TREASURY_CAP_ID

# Deploy the package to mainnet
echo "Transferring Deny List Cap..."
echo "Target address: $ADMIN_ADDRESS"
echo "Deny Cap ID: $DENY_LIST_CAP_ID"
sui client transfer --to $ADMIN_ADDRESS --object-id $DENY_LIST_CAP_ID

echo "Burning upgrade cap..."
echo "Target address: ZERO_ADDRESS"
echo "Upgrade Cap ID: $UPGRADE_CAP_ID"
sui client transfer --to 0x0000000000000000000000000000000000000000000000000000000000000000 --object-id $UPGRADE_CAP_ID

echo "Full deployment success"