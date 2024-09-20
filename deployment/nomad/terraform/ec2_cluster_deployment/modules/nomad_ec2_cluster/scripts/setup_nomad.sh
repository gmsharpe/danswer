#!/bin/bash

PRIVATE_IP=$1
SERVER_IP=$2
IS_SERVER=$3

# remove for non-dev environments
export VAULT_ADDR="http://$SERVER_IP:8200"
# just in case export wasn't retained
export VAULT_TOKEN=$(grep 'Initial Root Token' /var/vault/keys/vault-init-output.txt | awk '{print $NF}')

# install nomad
sudo yum -y install nomad

# Install Docker
sudo yum install -y docker

# Start Docker and enable it to start on boot
sudo systemctl start docker
sudo systemctl enable docker

sudo mkdir -p /etc/nomad.d

# Create /opt/nomad directory and ensure correct permissions
sudo mkdir -p /opt/nomad
sudo chown -R nobody:nobody /opt/nomad
sudo chmod -R 755 /opt/nomad

if [ "$IS_SERVER" == "true" ]; then
  NODE_POOL="primary"
else
  NODE_POOL="secondary"
fi

### NOMAD ###

# Start the configuration file
cat <<EOT > /etc/nomad.d/nomad.hcl
EOT

# Conditionally add the server configuration
if [ "$IS_SERVER" == "true" ]; then
  cat <<EOT >> /etc/nomad.d/nomad.hcl
server {
  enabled = true
  bootstrap_expect = 1
}
bind_addr = "0.0.0.0"
ui {
  enabled = true
}
EOT
fi

# Append the rest of the configuration
cat <<EOT >> /etc/nomad.d/nomad.hcl
log_level = "DEBUG"
plugin "docker" {
  config {
    allow_privileged = true
    volumes {
      enabled = true
    }
  }
}
# Enable Vault integration in Nomad
vault {
  enabled = true
  address = "http://$SERVER_IP:8200"  # Vault server address
  token   = "YOUR_VAULT_TOKEN"         # Token with access to Vault policies
}
client {
  enabled = true
  servers = ["$SERVER_IP"]
  node_pool  = "$NODE_POOL"
  meta {
    node_pool = "$NODE_POOL"
  }
  options {
    "driver.raw_exec.enable" = "true"
    "driver.exec.enable" = "true"
    "driver.docker.enable" = "true"
  }
}
data_dir = "/opt/nomad"
advertise {
  http = "$PRIVATE_IP"
  rpc = "$PRIVATE_IP"
  serf = "$PRIVATE_IP"
}
EOT

# setup NOMAD_VAULT_TOKEN
# If you have a token for Nomad to access Vault, configure the token permissions in Vault
echo "Setting up Vault policies and token for Nomad..."

# Configure a policy for Nomad in Vault
vault policy write nomad-server - <<EOT
path "auth/token/create" {
  capabilities = ["update"]
}
path "auth/token/roles/nomad-cluster" {
  capabilities = ["read"]
}
path "auth/token/lookup-self" {
  capabilities = ["read"]
}
path "sys/capabilities-self" {
  capabilities = ["read"]
}
path "sys/leases/renew" {
  capabilities = ["update"]
}
path "sys/leases/revoke" {
  capabilities = ["update"]
}
EOT

# Create a token with the Nomad policy
NOMAD_VAULT_TOKEN=$(vault token create -policy="nomad-server" -field token)

if [ -z "$NOMAD_VAULT_TOKEN" ]; then
  echo "Error creating Vault token."
  exit 1
fi

echo "Vault token for Nomad: $NOMAD_VAULT_TOKEN"

# Substitute the generated token into Nomad config (or pass it securely)
sed -i "s/YOUR_VAULT_TOKEN/$NOMAD_VAULT_TOKEN/" /etc/nomad.d/nomad.hcl

cat <<EOT >> /var/vault/keys/keys.txt
nomad_vault_token=$NOMAD_VAULT_TOKEN
EOT


# Create a systemd service file for Nomad
cat <<EOT > /etc/systemd/system/nomad.service
[Unit]
Description=Nomad
Documentation=https://www.nomadproject.io/docs/
[Service]
ExecStart=/usr/bin/nomad agent -config=/etc/nomad.d/nomad.hcl
ExecReload=/bin/kill -HUP $MAINPID
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOT

# Enable the service so it starts on boot
echo "Starting Nomad..."
sudo systemctl enable nomad
sudo systemctl start nomad