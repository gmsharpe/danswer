#!/bin/bash

# Function to display usage information
usage() {
  echo "Usage: $0 -location <location> -root_key <root_key_value> -unseal_keys <unseal_keys_json> [-vault_id <vault_id>]"
  echo "Currently supported location: 'ssm'"
  exit 1
}

# Initialize variables
LOCATION="ssm"
ROOT_KEY=""
UNSEAL_KEYS_JSON=""
VAULT_ID=""

# Get the current date in 'MM-DD-YYYY' format
CURRENT_DATE=$(date +'%m-%d-%Y')

# Parse the named arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -location)
      LOCATION="$2"
      shift 2
      ;;
    -root_key)
      ROOT_KEY="$2"
      shift 2
      ;;
    -unseal_keys)
      UNSEAL_KEYS_JSON="$2"
      shift 2
      ;;
    -vault_id)
      VAULT_ID="$2"
      shift 2
      ;;
    *)
      echo "Invalid argument: $1"
      usage
      ;;
  esac
done

# Validate that required arguments are provided
if [ -z "$LOCATION" ] || [ -z "$ROOT_KEY" ] || [ -z "$UNSEAL_KEYS_JSON" ]; then
  echo "Error: Missing required arguments."
  usage
fi

# If no vault_id is provided, set it to the default format 'vault-mm-dd-yyyy'
if [ -z "$VAULT_ID" ]; then
  VAULT_ID="vault-for-nomad-cluster"
fi

# Check if the location is 'ssm' and call the corresponding script
if [ "$LOCATION" == "ssm" ]; then
  # Call the store_vault_keys_ssm_param_store.sh script
  ./vault/scripts/store_vault_keys_ssm_param_store.sh -root_key "$ROOT_KEY" -unseal_keys "$UNSEAL_KEYS_JSON" -vault_id "$VAULT_ID"
else
  # No alternative is currently defined, so exit with an error
  echo "Error: Unsupported location '$LOCATION'. Currently only 'ssm' is supported."
  exit 1
fi
