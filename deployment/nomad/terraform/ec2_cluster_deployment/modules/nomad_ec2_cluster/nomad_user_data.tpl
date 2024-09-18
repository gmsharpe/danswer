#!/bin/bash
sudo yum update -y
sudo yum install -y wget unzip
sudo yum install -y yum-utils shadow-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
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

# Use EC2 metadata service to get the instance's private IP
PRIVATE_IP=${private_ip} #$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

# convert variables to uppercase for consistency
INSTALL_CONSUL=${install_consul}
INSTALL_DANSWER=${install_danswer}
INSTALL_VAULT=${install_vault}

# Determine if this instance should include the server configuration
IS_SERVER="${count == 0 ? "true" : "false"}"

if [ "$IS_SERVER" == "true" ]; then
  NODE_POOL="primary"
else
  NODE_POOL="secondary"
fi


# Install Vault if required
if [ "$INSTALL_VAULT" == "true" ]; then
  sudo yum -y install vault

  # Configure Vault
  cat <<EOT > /etc/vault.d/vault.hcl
storage "file" {
  path = "/var/nomad/volumes/vault"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}

api_addr = "http://$PRIVATE_IP:8200"
cluster_addr = "http://$PRIVATE_IP:8201"
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
fi

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
# used to have bind_addr = "0.0.0.0" in the client configuration

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
  address = "http://$PRIVATE_IP:8200"  # Vault server address
  token   = "YOUR_VAULT_TOKEN"         # Token with access to Vault policies
}
client {
  enabled = true
  servers = ["${server_ip}"]
  node_pool  = "$NODE_POOL"
  meta {
    node_pool = "$NODE_POOL"
  }
  options {
    "driver.raw_exec.enable" = "true"
    "driver.exec.enable" = "true"
    "driver.docker.enable" = "true"
  }

  # Register the DB volume
  host_volume "db" {
    path      = "/var/nomad/volumes/danswer/db"  # Path on the host machine
    read_only = false                           # Allow read-write access
  }

  # Register the Vespa volume
  host_volume "vespa" {
    path      = "/var/nomad/volumes/danswer/vespa"
    read_only = false
  }

  # Register the Huggingface model cache volume
  host_volume "model_cache_huggingface" {
    path      = "/var/nomad/volumes/danswer/model_cache_huggingface"
    read_only = false
  }

  # Register the indexing model cache volume
  host_volume "indexing_model_cache_huggingface" {
    path      = "/var/nomad/volumes/danswer/indexing_model_cache_huggingface"
    read_only = false
  }

  # Register the Nginx configuration volume
  host_volume "nginx" {
    path      = "/var/nomad/volumes/danswer/nginx"
    read_only = false
  }

  host_volume "vault" {
    path      = "/var/nomad/volumes/vault"
    read_only = false
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
if [ "$INSTALL_VAULT" == "true" ]; then
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
  echo "Vault token for Nomad: $NOMAD_VAULT_TOKEN"

  # Substitute the generated token into Nomad config (or pass it securely)
  sed -i "s/YOUR_VAULT_TOKEN/$NOMAD_VAULT_TOKEN/" /etc/nomad.d/nomad.hcl
fi

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

# Create the directories for the Nomad volumes
sudo mkdir -p /var/nomad/volumes/danswer/{db,vespa,nginx,indexing_model_cache_huggingface,model_cache_huggingface}
sudo mkdir -p /var/nomad/volumes/vault

# Enable the service so it starts on boot
sudo systemctl enable nomad
sudo systemctl start nomad


# Install and configure Consul if required
if [ "$INSTALL_CONSUL" == "true" ]; then
  sudo yum -y install consul

  # Configure Consul
  cat <<EOT > /etc/consul.d/consul.hcl
data_dir = "/opt/consul"
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
advertise_addr = "$PRIVATE_IP"
retry_join = ["${server_ip}"]
datacenter = "dc1"
EOT

  cat <<EOT >> /etc/consul.d/consul.hcl
server = true
bootstrap_expect = 3
ui_config {
  enabled = true
}
EOT


  # Create Consul systemd service
  cat <<EOT > /etc/systemd/system/consul.service
[Unit]
Description=Consul Agent
Documentation=https://www.consul.io/docs/
After=network.target
[Service]
ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOT

  sudo systemctl enable consul
  sudo systemctl start consul
fi

# Install Danswer if required
#if [ "$INSTALL_DANSWER" == "true" ]; then
echo "Preparing to install Danswer"
sudo mkdir -p /opt/danswer && \
  sudo chown -R nobody:nobody /opt/danswer && \
  sudo chmod -R 755 /opt/danswer

sudo yum install -y git && \
  cd /opt/danswer && \
  sudo git clone https://github.com/gmsharpe/danswer.git .

# Copy nginx files
sudo cp -r /opt/danswer/deployment/data/nginx /var/nomad/volumes/danswer

  #cd /opt/danswer/deployment/nomad
  #sudo nomad run danswer.nomad.hcl > /dev/null 2>&1 &
#fi

