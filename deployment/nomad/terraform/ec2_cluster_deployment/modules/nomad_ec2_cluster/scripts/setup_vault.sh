#!/bin/bash

set -euo pipefail

# Default values
DEFAULT_PRIVATE_IP="10.0.1.10"
DEFAULT_LEADER_IP="10.0.1.10"
DEFAULT_IS_SERVER="true"
DEFAULT_IS_LEADER="true"

# Assign variables, using defaults if arguments are not provided
PRIVATE_IP="${1:-$DEFAULT_PRIVATE_IP}"   # The private IP address of the current node
LEADER_IP="${2:-$DEFAULT_LEADER_IP}"     # The private IP address of the leader node
IS_SERVER="${3:-$DEFAULT_IS_SERVER}"     # "true" if the node is a server
IS_LEADER="${4:-$DEFAULT_IS_LEADER}"     # "true" if the node is the leader (only one leader)

# Ensure vault user exists
#if ! id -u vault &>/dev/null; then
#  sudo useradd --system --home /etc/vault.d --shell /bin/false vault
#fi

# Set VAULT_ADDR environment variable
VAULT_ADDR="http://$LEADER_IP:8200"
sudo bash -c "echo 'export VAULT_ADDR=$VAULT_ADDR' > /etc/profile.d/vault.sh"
sudo chmod 644 /etc/profile.d/vault.sh
echo "VAULT_ADDR is set to $VAULT_ADDR. Please log out and back in or run 'source /etc/profile.d/vault.sh' to apply the changes."

### VAULT ###

# Add HashiCorp repository and install Vault
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum -y install vault

if [ "$IS_SERVER" == "true" ]; then
  # Create data directory for Raft storage
  sudo mkdir -p /opt/vault/data
  sudo chown vault:vault /opt/vault/data

  # Configure Vault with Raft storage and clustering settings
  sudo tee /etc/vault.d/vault.hcl > /dev/null <<EOT
storage "raft" {
  path    = "/opt/vault/data"
  node_id = "vault-node-$PRIVATE_IP"

  retry_join {
    leader_api_addr = "http://$LEADER_IP:8200"
  }
}

listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable     = "true"  # Consider enabling TLS
}

api_addr     = "http://$PRIVATE_IP:8200"
cluster_addr = "http://$PRIVATE_IP:8201"

ui            = true
disable_mlock = true
EOT

  # Create Vault systemd service
  sudo tee /etc/systemd/system/vault.service > /dev/null <<EOT
[Unit]
Description=Vault Server
Documentation=https://www.vaultproject.io/docs/
After=network.target

[Service]
User=vault
Group=vault
ExecStart=/usr/bin/vault server -config=/etc/vault.d/vault.hcl
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target
EOT

  # Start Vault service
  sudo systemctl daemon-reload
  sudo systemctl enable vault
  sudo systemctl start vault

  # Ensure VAULT_ADDR is available for subsequent commands
  export VAULT_ADDR="http://$PRIVATE_IP:8200"

  if [ "$IS_LEADER" == "true" ]; then
    # Initialize Vault only on the leader node
    echo "Initializing Vault on leader node..."

    # Initialize Vault with multiple key shares and threshold for better security
    sudo -u vault env VAULT_ADDR="$VAULT_ADDR" vault operator init -key-shares=5 -key-threshold=3 | sudo tee /opt/vault/data/vault-init-output.txt > /dev/null

    # Extract root token and unseal keys
    root_token=$(grep 'Initial Root Token' /opt/vault/data/vault-init-output.txt | awk '{print $NF}')
    unseal_keys=$(grep 'Unseal Key ' /opt/vault/data/vault-init-output.txt | awk '{print $NF}')

    # Save unseal keys and root token securely
    sudo tee /opt/vault/data/keys.txt > /dev/null <<EOT
vault_root_token=$root_token
vault_unseal_keys=$unseal_keys
EOT
    sudo chmod 600 /opt/vault/data/keys.txt

    # Unseal Vault using multiple keys
    IFS=$'\n' read -d '' -r -a keys <<< "$unseal_keys"
    for key in "${keys[@]}"; do
      sudo -u vault VAULT_ADDR=$VAULT_ADDR vault operator unseal "$key"
    done

    # Set VAULT_TOKEN for further operations
    export VAULT_TOKEN="$root_token"

    # Enable KV secrets engine at 'secret' path
    sudo -u vault VAULT_ADDR=$VAULT_ADDR VAULT_TOKEN=$VAULT_TOKEN vault secrets enable -path=secret kv-v2

    echo "Vault is initialized and unsealed on the leader node."
  else
    # Wait for the leader to be ready
    echo "Waiting for Vault leader to be ready..."
    while true; do
      status_code=$(curl -s -o /dev/null -w "%{http_code}" http://$LEADER_IP:8200/v1/sys/health)
      if [ "$status_code" -eq 200 ] || [ "$status_code" -eq 429 ]; then
        echo "Vault leader is ready."
        break
      else
        echo "Vault leader not ready yet (status code: $status_code). Retrying in 5 seconds..."
        sleep 5
      fi
    done

    # Unseal the follower node using the leader's unseal keys
    echo "Unsealing Vault on follower node..."

    # Retrieve unseal keys securely (consider using a more secure method)
    for i in {1..5}; do
      unseal_key=$(ssh user@$LEADER_IP "sudo grep 'vault_unseal_keys' /opt/vault/data/keys.txt | cut -d'=' -f2 | tr ',' '\n' | head -n1")
      if [ -n "$unseal_key" ]; then
        break
      fi
      echo "Failed to retrieve unseal key. Retrying in 5 seconds..."
      sleep 5
    done

    if [ -z "$unseal_key" ]; then
      echo "Error: Unable to retrieve unseal key from leader node."
      exit 1
    fi

    sudo -u vault VAULT_ADDR=$VAULT_ADDR vault operator unseal "$unseal_key"
    echo "Vault is unsealed on the follower node."
  fi
else
  # Configure Vault client on non-server nodes
  echo "Configuring Vault client..."
  sudo bash -c "echo 'export VAULT_ADDR=\"http://$LEADER_IP:8200\"' > /etc/profile.d/vault_client.sh"
  sudo chmod 644 /etc/profile.d/vault_client.sh
  echo "Vault client is configured to communicate with the leader at $LEADER_IP. Please log out and back in or run 'source /etc/profile.d/vault_client.sh' to apply the changes."
fi
