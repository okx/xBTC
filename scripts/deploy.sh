  # Build the package
  echo "Building xBTC package..."
  sui move build

  # Deploy the package to mainnet
  echo "Deploying xBTC package..."
  DEPLOY_OUTPUT=$(sui client publish --gas-budget 100000000)

  # Write the deployment output to a file for debugging
  echo "$DEPLOY_OUTPUT" > deploy_output.txt
  echo "Full deployment output saved to deploy_output.txt"