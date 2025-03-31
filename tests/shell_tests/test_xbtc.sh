#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

CONFIG_FILE="xbtc_config.txt"

echo -e "${GREEN}Starting xBTC token test script...${NC}"

# Navigate to the right directory
cd "$(dirname "$0")/.."

# Check if the config file exists and load from it if available
if [ -f "$CONFIG_FILE" ]; then
  echo -e "${GREEN}Loading configuration from $CONFIG_FILE...${NC}"
  source "$CONFIG_FILE"

  # Verify all required parameters are loaded
  if [ -n "$PACKAGE_ID" ] && [ -n "$TREASURY_CAP_ID" ] && [ -n "$DENY_CAP_ID" ] && [ -n "$RECEIVER_ID" ]; then
    echo -e "${GREEN}Loaded parameters:${NC}"
    echo -e "${GREEN}Package ID: $PACKAGE_ID${NC}"
    echo -e "${GREEN}Treasury Cap: $TREASURY_CAP_ID${NC}"
    echo -e "${GREEN}Deny Cap: $DENY_CAP_ID${NC}"
    echo -e "${GREEN}Deny List: $DENY_LIST_ID${NC}"
    echo -e "${GREEN}Receiver: $RECEIVER_ID${NC}"
    echo -e "${GREEN}Test Address: $RECIPIENT${NC}"
  else
    echo -e "${YELLOW}Configuration file incomplete. Redeploying...${NC}"
    rm -f "$CONFIG_FILE"
  fi
fi

# If parameters weren't loaded from config file, deploy and extract them
if [ -z "$PACKAGE_ID" ] || [ -z "$TREASURY_CAP_ID" ] || [ -z "$DENY_CAP_ID" ] || [ -z "$RECEIVER_ID" ]; then
  # Build the package
  echo -e "${GREEN}Building xBTC package...${NC}"
  sui move build

  # Deploy the package to mainnet
  echo -e "${GREEN}Deploying xBTC package...${NC}"
  DEPLOY_OUTPUT=$(sui client publish --gas-budget 100000000)

  # Write the deployment output to a file for debugging
  echo "$DEPLOY_OUTPUT" > deploy_output.txt
  echo "Full deployment output saved to deploy_output.txt"

  # Extract package ID - look for the PackageID pattern
  PACKAGE_ID=$(echo "$DEPLOY_OUTPUT" | grep -A 1 "PackageID:" | grep -o "0x[a-zA-Z0-9]*")

  if [ -z "$PACKAGE_ID" ]; then
    # Alternative extraction method for published objects
    PACKAGE_ID=$(echo "$DEPLOY_OUTPUT" | grep -A 5 "Published Objects:" | grep -o "0x[a-zA-Z0-9]*" | head -1)
  fi

  if [ -z "$PACKAGE_ID" ]; then
    echo -e "${RED}Failed to extract Package ID. Check deploy_output.txt for details.${NC}"
    exit 1
  fi

  echo -e "${GREEN}Package ID: $PACKAGE_ID${NC}"

  # Extract object IDs from the deployment
  echo -e "${GREEN}Extracting object IDs from deployment output...${NC}"

  # Find the TreasuryCap, DenyCapV2, and XBTCReceiver entries
  TREASURY_CAP_LINES=$(grep -n "TreasuryCap<.*xbtc::XBTC" deploy_output.txt || echo "")
  DENY_CAP_LINES=$(grep -n "DenyCapV2<.*xbtc::XBTC" deploy_output.txt || echo "")
  RECEIVER_LINES=$(grep -n "XBTCReceiver" deploy_output.txt || echo "")

  # Extract the object IDs from the surrounding lines
  if [ -n "$TREASURY_CAP_LINES" ]; then
    # Get the line number
    LINE_NUM=$(echo "$TREASURY_CAP_LINES" | head -1 | cut -d: -f1)
    # Extract the object ID from the surrounding lines near that line number
    TREASURY_CAP_ID=$(grep -A 5 -B 5 "TreasuryCap<.*xbtc::XBTC" deploy_output.txt | grep "ObjectID:" | head -1 | grep -o "0x[a-zA-Z0-9]*")
  fi

  if [ -n "$DENY_CAP_LINES" ]; then
    # Get the line number
    LINE_NUM=$(echo "$DENY_CAP_LINES" | head -1 | cut -d: -f1)
    # Extract the object ID from the surrounding lines near that line number
    DENY_CAP_ID=$(grep -A 5 -B 5 "DenyCapV2<.*xbtc::XBTC" deploy_output.txt | grep "ObjectID:" | head -1 | grep -o "0x[a-zA-Z0-9]*")
  fi

  if [ -n "$RECEIVER_LINES" ]; then
    # Get the line number
    LINE_NUM=$(echo "$RECEIVER_LINES" | head -1 | cut -d: -f1)
    # Extract the object ID from the surrounding lines near that line number
    RECEIVER_ID=$(grep -A 5 -B 5 "XBTCReceiver" deploy_output.txt | grep "ObjectID:" | head -1 | grep -o "0x[a-zA-Z0-9]*")
  fi

  # For DenyList, we use the default 0x403 object
  DENY_LIST_ID="0x403"

  # Log the extracted IDs
  echo -e "${GREEN}Treasury Cap: $TREASURY_CAP_ID${NC}"
  echo -e "${GREEN}Deny Cap: $DENY_CAP_ID${NC}"
  echo -e "${GREEN}Deny List: $DENY_LIST_ID${NC}"
  echo -e "${GREEN}Receiver: $RECEIVER_ID${NC}"

  # Check if we have all the required object IDs
  if [ -z "$TREASURY_CAP_ID" ] || [ -z "$DENY_CAP_ID" ] || [ -z "$RECEIVER_ID" ]; then
    echo -e "${RED}Failed to extract one or more required object IDs from deployment output.${NC}"
    echo -e "${RED}Please check deploy_output.txt and update the script accordingly.${NC}"
    exit 1
  fi

  # Save the parameters to the config file for future runs
  echo -e "${GREEN}Saving configuration to $CONFIG_FILE for future use...${NC}"
  {
    echo "PACKAGE_ID=$PACKAGE_ID"
    echo "TREASURY_CAP_ID=$TREASURY_CAP_ID"
    echo "DENY_CAP_ID=$DENY_CAP_ID"
    echo "DENY_LIST_ID=$DENY_LIST_ID"
    echo "RECEIVER_ID=$RECEIVER_ID"
  } > "$CONFIG_FILE"
fi

# Export these values as environment variables
export PACKAGE_ID
export TREASURY_CAP_ID
export DENY_CAP_ID
export DENY_LIST_ID
export RECEIVER_ID

# Get current address
CURRENT_ADDRESS=$(sui client active-address)
echo -e "${GREEN}Current address: $CURRENT_ADDRESS${NC}"
export CURRENT_ADDRESS

# Change the receiver to Sender address
echo -e "${GREEN}Changing receiver to sender address...${NC}"
sui client call --package $PACKAGE_ID --module xbtc --function set_receiver \
  --args $TREASURY_CAP_ID $RECEIVER_ID $CURRENT_ADDRESS \
  --gas-budget 10000000

# Mint some xBTC to the sender address
echo -e "${GREEN}Minting 100000000 xBTC (1 BTC) to sender...${NC}"
sui client call --package $PACKAGE_ID --module xbtc --function mint \
  --args $TREASURY_CAP_ID $RECEIVER_ID 100000000 $CURRENT_ADDRESS \
  --gas-budget 10000000

# Change receiver to recipient address
echo -e "${GREEN}Changing receiver to recipient address...${NC}"
sui client call --package $PACKAGE_ID --module xbtc --function set_receiver \
  --args $TREASURY_CAP_ID $RECEIVER_ID $RECIPIENT \
  --gas-budget 10000000

# Mint some xBTC to the recipient address
echo -e "${GREEN}Minting 100000000 xBTC (1 BTC) to recipient...${NC}"
sui client call --package $PACKAGE_ID --module xbtc --function mint \
  --args $TREASURY_CAP_ID $RECEIVER_ID 100000000 $RECIPIENT \
  --gas-budget 10000000

# Check if deny list is properly configured (not the default 0x2 object)
if [ "$DENY_LIST_ID" == "0x403" ]; then
  echo -e "${GREEN}Deny list is properly configured. Running blacklist tests...${NC}"

  # Test by adding an address to deny list
  echo -e "${GREEN}Adding recipient to deny list...${NC}"
  sui client call --package $PACKAGE_ID --module xbtc --function add_to_deny_list \
    --args $DENY_LIST_ID $DENY_CAP_ID $RECIPIENT \
    --gas-budget 10000000

  # Test if we can mint to the deny list address
  echo -e "${GREEN}Minting to deny list address...${NC}"
  sui client call --package $PACKAGE_ID --module xbtc --function mint \
    --args $TREASURY_CAP_ID $RECEIVER_ID 100000000 $RECIPIENT \
    --gas-budget 10000000

  # Test pause functionality
  echo -e "${GREEN}Testing global pause...${NC}"
  sui client call --package $PACKAGE_ID --module xbtc --function set_pause \
    --args $DENY_LIST_ID $DENY_CAP_ID true \
    --gas-budget 10000000

  # Disable pause
  echo -e "${GREEN}Disabling global pause...${NC}"
  sui client call --package $PACKAGE_ID --module xbtc --function set_pause \
    --args $DENY_LIST_ID $DENY_CAP_ID false \
    --gas-budget 10000000

  # Remove from deny list
  echo -e "${GREEN}Removing recipient from deny list...${NC}"
  sui client call --package $PACKAGE_ID --module xbtc --function remove_from_deny_list \
    --args $DENY_LIST_ID $DENY_CAP_ID $RECIPIENT \
    --gas-budget 10000000

  # Test batch operations
  echo -e "${GREEN}Testing batch operation by adding a list of addresses to deny list...${NC}"
  sui client call --package $PACKAGE_ID --module xbtc --function batch_add_to_deny_list \
    --args $DENY_LIST_ID $DENY_CAP_ID "[$RECIPIENT]" \
    --gas-budget 10000000

  echo -e "${GREEN}Removing batch addresses from deny list...${NC}"
  sui client call --package $PACKAGE_ID --module xbtc --function batch_remove_from_deny_list \
    --args $DENY_LIST_ID $DENY_CAP_ID "[$RECIPIENT]" \
    --gas-budget 10000000

  # Test batch operations
  echo -e "${GREEN}Testing batch operation by adding a list of addresses to deny list...${NC}"
  sui client call --package $PACKAGE_ID --module xbtc --function batch_add_to_deny_list \
    --args $DENY_LIST_ID $DENY_CAP_ID "[$RECIPIENT]" \
    --gas-budget 10000000
fi

echo -e "${GREEN}All tests completed!${NC}"
echo -e "${GREEN}xBTC token deployed and tested.${NC}"
echo -e "${GREEN}Summary of important IDs:${NC}"
echo -e "${GREEN}Package ID: $PACKAGE_ID${NC}"
echo -e "${GREEN}Treasury Cap: $TREASURY_CAP_ID${NC}"
echo -e "${GREEN}Deny Cap: $DENY_CAP_ID${NC}"
echo -e "${GREEN}Deny List: $DENY_LIST_ID${NC}"
echo -e "${GREEN}Receiver: $RECEIVER_ID${NC}"