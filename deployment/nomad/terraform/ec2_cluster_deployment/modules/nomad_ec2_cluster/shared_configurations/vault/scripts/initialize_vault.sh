#!/bin/bash

IS_SERVER=${IS_SERVER:-true}
VAULT_PROFILE_SCRIPT=/etc/profile.d/vault.sh

# unseal vault if not in dev mode
if [ "$IS_SERVER" == "true" ]; then
  # if there is more than one 'server', this configuration would need to be adjusted to account for that by
  #    1st checking if the server is the designated leader (or first configured server) and then unsealing
  #    2nd checking if the server is a follower and then joining the leader (or first configured server) and then unsealing

  # backup the vault-init-output.txt file, if present
  if [ -f /opt/vault/data/vault-init-output.txt ]; then
      sudo mv /opt/vault/data/vault-init-output.txt /opt/vault/data/vault-init-output.txt.bak
  fi

  # Set VAULT_ADDR for further operations
  # todo - should use 'https' later
  VAULT_ADDR=http://127.0.0.1:8200

  # Initialize Vault with multiple key shares and threshold for better security
  echo "Initialize Vault"
  sudo -u vault env VAULT_ADDR="$VAULT_ADDR" vault operator init -key-shares=1 -key-threshold=1 | sudo tee /opt/vault/data/vault-init-output.txt > /dev/null

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
export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=$VAULT_TOKEN
PROFILE

  echo "Unsealing Vault"
  sudo -u vault VAULT_ADDR=$VAULT_ADDR vault operator unseal "$unseal_key"

  # Enable KV secrets engine at 'secret' path
  echo "Enable KV secrets engine with path = 'secret'"
  sudo -u vault VAULT_ADDR=$VAULT_ADDR VAULT_TOKEN=$VAULT_TOKEN vault secrets enable -path=secret kv-v2

  echo "Vault is initialized and unsealed on the leader node."
fi