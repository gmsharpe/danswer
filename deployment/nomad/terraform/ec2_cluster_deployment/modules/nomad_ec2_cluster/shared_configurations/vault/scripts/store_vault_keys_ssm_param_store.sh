#!/bin/bash

# This script stores Vault's root key and unseal keys in AWS Systems Manager (SSM) Parameter Store.
# The script accepts three named arguments:
#   -root_key: The Vault root key to be stored.
#   -unseal_keys: The Vault unseal keys as a JSON object to be stored.
#   -vault_id: A unique identifier for the Vault instance, used to organize the parameters in SSM.
#
# The script stores the root key and unseal keys under SSM parameter paths:
#   /<vault_id>/root-key
#   /<vault_id>/unseal-keys
#
# Both parameters are stored as SecureString, and encryption is handled by AWS KMS.
# The script uses AWS CLI to interact with SSM and checks the success of each operation.
#
# Usage Example:
#   ./store_vault_keys.sh -root_key 'my_root_key_value' \
#                         -unseal_keys '{"unseal_key_1": "key_value_1", "unseal_key_2": "key_value_2", "unseal_key_3": "key_value_3"}' \
#                         -vault_id 'my_vault_id'


# Function to display usage information
usage() {
  echo "Usage: $0 -root_key <root_key_value> -unseal_keys <unseal_keys_json> -vault_id <vault_id>"
  exit 1
}

# Initialize variables
ROOT_KEY=""
UNSEAL_KEYS_JSON=""
VAULT_ID=""

# Parse the named arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
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

# Validate that all required arguments are provided
if [ -z "$ROOT_KEY" ] || [ -z "$UNSEAL_KEYS_JSON" ] || [ -z "$VAULT_ID" ]; then
  echo "Error: Missing required arguments."
  usage
fi

# Store the root key in AWS SSM Parameter Store
echo "Storing the root key in SSM Parameter Store with Vault ID $VAULT_ID..."
aws ssm put-parameter \
  --name "/${VAULT_ID}/root-key" \
  --value "$ROOT_KEY" \
  --type "SecureString" \
  --key-id "$KMS_KEY_ALIAS" \
  --overwrite

if [ $? -eq 0 ]; then
  echo "Root key successfully stored in SSM Parameter Store."
else
  echo "Failed to store the root key in SSM Parameter Store."
  exit 1
fi

# Store the unseal keys JSON in AWS SSM Parameter Store
echo "Storing the unseal keys JSON in SSM Parameter Store with Vault ID $VAULT_ID..."
aws ssm put-parameter \
  --name "/${VAULT_ID}/unseal-keys" \
  --value "$UNSEAL_KEYS_JSON" \
  --type "SecureString" \
  --overwrite

if [ $? -eq 0 ]; then
  echo "Unseal keys successfully stored in SSM Parameter Store."
else
  echo "Failed to store the unseal keys in SSM Parameter Store."
  exit 1
fi

echo "All keys have been successfully stored in AWS SSM Parameter Store."
