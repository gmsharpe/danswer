#!/bin/bash

PRIVATE_IP=$1
SERVER_IP=$2
IS_SERVER=$3

### VAULT ###

if [ "$IS_SERVER" == "true" ]; then
  sudo yum -y install vault

  # Configure Vault
  cat <<EOT > /etc/vault.d/vault.hcl
storage "file" {
  path = "/var/nomad/volumes/vault"
}

listener "tcp" {
 address         = "0.0.0.0:8200"
 cluster_address = "0.0.0.0:8201"
 tls_disable     = "true"
}

api_addr = "http://$PRIVATE_IP:8200"
cluster_addr = "http://$PRIVATE_IP:8201"

ui = true
disable_mlock = true
EOT

  # Create Vault systemd service
  cat <<EOT > /etc/systemd/system/vault.service
[Unit]
Description=Vault
Documentation=https://www.vaultproject.io/docs/
[Service]
ExecStart=/usr/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOT

  sudo systemctl enable vault
  sudo systemctl start vault

  export VAULT_ADDR="http://$SERVER_IP:8200"

  # Wait for Vault to be fully started by checking the API
  echo "Waiting for Vault to start..."
  while true; do
    status_code=$(curl -s -o /dev/null -w "%{http_code}" http://$SERVER_IP:8200/v1/sys/health)

    # Ensure the status code is not empty or null
    if [ -z "$status_code" ]; then
      echo "Failed to retrieve status code. Retrying in 5 seconds..."
      sleep 5
      continue
    fi

    # 200: Vault is initialized, unsealed, and active.
    # 429: Vault is unsealed and in standby mode.
    # 472: Vault is sealed.
    # 501: Vault is not initialized.
    if [ "$status_code" -eq 501 ]; then
      echo "Vault is up and running!"
      break
    else
      echo "Vault is not ready yet (status code: $status_code). Retrying in 5 seconds..."
      sleep 5
    fi
  done

  sudo mkdir -p /var/vault/keys

  # Initialize Vault and save the output to a file
  vault operator init -key-shares=1 -key-threshold=1 > /var/vault/keys/vault-init-output.txt

  # Extract root token and unseal keys from the initialization output
  root_token=$(grep 'Initial Root Token' /var/vault/keys/vault-init-output.txt | awk '{print $NF}')
  unseal_key_1=$(grep 'Unseal Key 1' /var/vault/keys/vault-init-output.txt | awk '{print $NF}')

  # Unseal Vault with 1 unseal key
  vault operator unseal "$unseal_key_1"

  # Save unseal keys and root token to a secure file
  cat <<EOT > /var/vault/keys/keys.txt
unseal_key_1=$unseal_key_1
root_token=$root_token
EOT

  # Secure the file
  chmod 600 /var/vault/keys/keys.txt

  # Set the VAULT_TOKEN environment variable for remainder of this session
  export VAULT_TOKEN="$root_token"

  vault secrets enable -path=secret kv-v2

  echo "Vault is initialized and unsealed. Root token and unseal keys are stored in /var/vault/keys/keys.txt."
fi