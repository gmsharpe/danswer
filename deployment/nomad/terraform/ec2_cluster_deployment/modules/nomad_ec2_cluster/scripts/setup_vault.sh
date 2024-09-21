#!/bin/bash


# Default values
DEFAULT_PRIVATE_IP="10.0.1.10"
DEFAULT_LEADER_IP="10.0.1.10"
DEFAULT_IS_SERVER="false"
DEFAULT_IS_LEADER="false"

# Assign variables, using defaults if arguments are not provided
PRIVATE_IP=${1:-$DEFAULT_PRIVATE_IP}   # The private IP address of the current node
LEADER_IP=${2:-$DEFAULT_LEADER_IP}     # The private IP address of the leader node
IS_SERVER=${3:-$DEFAULT_IS_SERVER}     # "true" if the node is a server
IS_LEADER=${4:-$DEFAULT_IS_LEADER}     # "true" if the node is the leader (only one leader)


### VAULT ###

sudo yum -y install vault

if [ "$IS_SERVER" == "true" ]; then
  # Create data directory for Raft storage
  sudo mkdir -p /opt/vault/data
  sudo chown vault:vault /opt/vault/data

  # Configure Vault with Raft storage and clustering settings
  cat <<EOT > /etc/vault.d/vault.hcl
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
  tls_disable     = "true"
}

api_addr     = "http://$PRIVATE_IP:8200"
cluster_addr = "http://$PRIVATE_IP:8201"

ui            = true
disable_mlock = true
EOT

  # Create Vault systemd service
  cat <<EOT > /etc/systemd/system/vault.service
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

  # This should already be set, but just in case
  export VAULT_ADDR="http://$PRIVATE_IP:8200"

  # for now, the only 'server' will also be the 'leader'
  #if [ "$IS_LEADER" == "true" ]; then
  if [ "$IS_SERVER" == "true" ]; then
    # Initialize Vault only on the leader node
    echo "Initializing Vault on leader node..."
    vault operator init -key-shares=1 -key-threshold=1 > /opt/vault/data/vault-init-output.txt

    # Extract root token and unseal key
    root_token=$(grep 'Initial Root Token' /opt/vault/data/vault-init-output.txt | awk '{print $NF}')
    unseal_key=$(grep 'Unseal Key 1' /opt/vault/data/vault-init-output.txt | awk '{print $NF}')

    # Unseal Vault
    vault operator unseal "$unseal_key"

    # Save unseal key and root token securely
    cat <<EOT > /opt/vault/data/keys.txt
vault_unseal_key=$unseal_key
vault_root_token=$root_token
EOT
    chmod 600 /opt/vault/data/keys.txt

    # Set VAULT_TOKEN for further operations
    export VAULT_TOKEN="$root_token"

    # Enable KV secrets engine at 'secret' path
    vault secrets enable -path=secret kv-v2

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

    # Unseal the follower node using the leader's unseal key
    echo "Unsealing Vault on follower node..."
    unseal_key=$(ssh user@$LEADER_IP "sudo cat /opt/vault/data/keys.txt | grep 'unseal_key' | cut -d'=' -f2")
    vault operator unseal "$unseal_key"
    echo "Vault is unsealed on the follower node."
  fi
else
  # Configure Vault client on non-server nodes
  echo "Configuring Vault client..."
  echo "export VAULT_ADDR=\"http://$LEADER_IP:8200\"" >> ~/.bash_profile
  source ~/.bash_profile
  echo "Vault client is configured to communicate with the leader at $LEADER_IP."
fi
