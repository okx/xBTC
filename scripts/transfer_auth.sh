#!/bin/bash

MODULE_ADDR=""

NEW_MINTER=""
NEW_DENYLISTER=""

echo "Transferring minter role..."
aptos move run \
  --function-id ${MODULE_ADDR}::xbtc::transfer_minter_role \
  --args address:${NEW_MINTER} \
  --assume-yes \
  --profile default

echo "Minter role transferred."

echo "Transferring denylister role..."
aptos move run \
  --function-id ${MODULE_ADDR}::xbtc::transfer_denylister_role \
  --args address:${NEW_DENYLISTER} \
  --assume-yes \
  --profile default

echo "✅ Denylister role transferred."
