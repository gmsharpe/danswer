#!/bin/bash

echo -e "\nRunning initialize-vault.sh"
echo "#############################################"
echo "### Initialize and unseal Vault on leader ###"
echo -e "#############################################\n"

# Usage function to display help
usage() {
  echo "Usage: $0 [options]"
  echo
  echo "Options:"
  echo "  -vault_id              Specify the vault ID."
  echo "  -is_server             Specify if this is a server (true/false)."
  echo "  -num_key_shares        Number of key shares."
  echo "  -num_key_threshold     Number of key shares required to unseal."
  echo "  -save_keys_externally  Specify if keys should be saved externally (true/false)."
  echo "  -server_ip             Specify the server IP address."
  echo
  echo "Example:"
  echo "  $0 -vault_id 1234 -is_server true -num_key_shares 5 -num_key_threshold 3 -save_keys_externally false"
  echo
  exit 1
}

is_server=${is_server:-true}
VAULT_PROFILE_SCRIPT=/etc/profile.d/vault.sh

# Get the current date in 'MM-DD-YYYY' format
current_date=$(date +'%m-%d-%Y')
default_vault_id="vault-${current_date}"

# Check if vault_id is provided as an argument, otherwise default
vault_id="${1:-$default_vault_id}"
num_key_shares=${num_key_shares:-1}
num_key_threshold=${num_key_threshold:-1}
save_keys_externally=${save_keys_externally:-false}


# Parse the named arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -vault_id)
      vault_id="$2"
      shift 2
      ;;
    -is_server)
      is_server="$2"
      shift 2
      ;;
    -server_ip)
      server_ip="$2"
      shift 2
      ;;
    -num_key_shares)
      num_key_shares="$2"
      shift 2
      ;;
    -num_key_threshold)
      num_key_threshold="$2"
      shift 2
      ;;
    -save_keys_externally)
      save_keys_externally="$2"
      shift 2
      ;;
    *)
      echo "Invalid argument: $1"
      usage
      ;;
  esac
done

echo "is_server = $is_server"
echo "server_ip = $server_ip"
echo "vault_id = $vault_id"
echo "num_key_shares = $num_key_shares"
echo "num_key_threshold = $num_key_threshold"
echo "save_keys_externally = $save_keys_externally"


# wait for vault by calling the http://<server_ip>:8200/v1/sys/seal-status endpoint
# fail after 5 attempts with 6 seconds between each attempt
function wait_for_vault_service() {
  local attempts=0
  local max_attempts=20
  local wait_time=6
  local server_ip=${server_ip}

  while [ $attempts -lt $max_attempts ]; do
    echo "Checking if Vault is ready... curl http://${server_ip}:8200/v1/sys/seal-status"
    response=$(curl -s -o /dev/null -w "%{http_code}" http://${server_ip}:8200/v1/sys/seal-status)
    if [ "$response" -eq 200 ]; then
      echo "Vault is ready."
      break
    else
      echo "Vault is not ready (status_code=$response).  Waiting..."
    fi
    attempts=$((attempts + 1))
    sleep $wait_time
  done

  if [ $attempts -eq $max_attempts ]; then
    echo "Vault is not ready.  Exiting."
    exit 1
  fi
}

wait_for_vault_service


# todo - should adjust to identify a 'leader' rather than use 'server' as the default
if [ "$is_server" = true ]; then
  # if there is more than one 'server', this configuration would need to be adjusted to account for that by
  #    1st checking if the server is the designated leader (or first configured server) and then unsealing
  #    2nd checking if the server is a follower and then joining the leader (or first configured server) and then unsealing

  # backup the vault-init-output.txt file, if present
  if [ -f /opt/vault/data/vault-init-output.txt ]; then
      sudo mv /opt/vault/data/vault-init-output.txt /opt/vault/data/vault-init-output.txt.bak
  fi

  # Set VAULT_ADDR for further operations
  # todo - should use 'https' later
  VAULT_ADDR=http://${server_ip}:8200

  # Initialize Vault with multiple key shares and threshold for better security
  echo "Initialize Vault with key shares = $num_key_shares and key threshold = $num_key_threshold."
  echo "Save output to /opt/vault/data/vault-init-output.txt"
  sudo -u vault env VAULT_ADDR="$VAULT_ADDR" vault operator init \
    -key-shares=$num_key_shares -key-threshold=$num_key_threshold | sudo tee /opt/vault/data/vault-init-output.txt > /dev/null

  # Extract root token and unseal keys
  root_token=$(grep 'Initial Root Token' /opt/vault/data/vault-init-output.txt | awk '{print $NF}')
  unseal_key=$(grep 'Unseal Key ' /opt/vault/data/vault-init-output.txt | awk '{print $NF}')

  # Save unseal keys and root token securely
  # if multiple unseal keys are generated, this file should be adjusted accordingly
  sudo tee /opt/vault/data/keys.txt > /dev/null <<EOT
vault_root_token=$root_token
vault_unseal_keys=$unseal_key
EOT
  sudo chmod 600 /opt/vault/data/keys.txt

  # Set VAULT_TOKEN for further operations
  VAULT_TOKEN="$root_token"

  # todo - should adjust for tls and other security measures later
  echo "Set Vault profile script"
  sudo tee ${VAULT_PROFILE_SCRIPT} > /dev/null <<PROFILE
export VAULT_ADDR=http://${server_ip}:8200
export VAULT_TOKEN=$VAULT_TOKEN
PROFILE

  echo "Unsealing Vault"
  sudo -u vault VAULT_ADDR=$VAULT_ADDR vault operator unseal "$unseal_key"

  # Enable KV secrets engine at 'secret' path
  echo "Enable KV secrets engine with path = 'secret'"
  sudo -u vault VAULT_ADDR=$VAULT_ADDR VAULT_TOKEN=$VAULT_TOKEN vault secrets enable -path=secret kv-v2

  echo "Vault is initialized and unsealed on the leader node."

  # Call store_vault_keys.sh to store the root token and unseal key in SSM Parameter Store
  echo "Storing Vault keys in SSM Parameter Store"

  # Construct unseal keys JSON object (if multiple unseal keys exist, modify accordingly)
  unseal_keys_json=$(jq -n --arg unseal_key_1 "$unseal_key" '{unseal_key_1: $unseal_key_1}')

  if [ "$save_keys_externally" = true ]; then
    # Call store_vault_keys.sh with appropriate arguments, using the default vault_id if not provided
    ./vault/scripts/store_vault_keys.sh -location 'ssm' \
                                        -root_key "$root_token" \
                                        -unseal_keys "$unseal_keys_json" \
                                        -vault_id "$vault_id"
  fi

else
  echo "Vault is not initialized and unsealed on the follower nodes.  By default the leader is the 'server' in this configuration."
fi

echo