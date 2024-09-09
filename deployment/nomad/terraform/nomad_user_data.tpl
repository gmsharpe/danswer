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

# Determine if this instance should include the server configuration
IS_SERVER="${count == 0 ? "true" : "false"}"

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
client {
  enabled = true
  servers = ["${server_ip}"]
}
data_dir = "/opt/nomad"
advertise {
  http = "$PRIVATE_IP"
  rpc = "$PRIVATE_IP"
  serf = "$PRIVATE_IP"
}
EOT
if [ "$IS_SERVER" == "true" ]; then
    sudo nomad agent -config=/etc/nomad.d/nomad.hcl -server &
else
    sudo nomad agent -config=/etc/nomad.d/nomad.hcl &
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

# Enable the service so it starts on boot
sudo systemctl enable nomad
sudo systemctl start nomad


# Conditionally install and configure Consul based on $INSTALL_CONSUL
if [ "$INSTALL_CONSUL" == "true" ]; then
  echo "Installing and configuring Consul..."

  sudo yum -y install nomad consul

  # Backup the existing Consul configuration file, if it exists
  if [ -f /etc/consul.d/consul.hcl ]; then
      sudo mv /etc/consul.d/consul.hcl /etc/consul.d/consul.hcl.bak
      echo "Backed up existing consul.hcl to consul.hcl.bak"
  fi

  # Create the new Consul configuration file
  cat <<EOT > /etc/consul.d/consul.hcl
data_dir = "/opt/consul"
bind_addr = "$PRIVATE_IP"
retry_join = ["${server_ip}"]
EOT

  # If this instance is a server, add the server-specific configuration for Consul
  if [ "$IS_SERVER" == "true" ]; then
    cat <<EOT >> /etc/consul.d/consul.hcl
server = true
bootstrap_expect = 1
ui = true
EOT
  fi

  # Create a systemd service file for Consul
  cat <<EOT > /etc/systemd/system/consul.service
[Unit]
Description=Consul Agent
Documentation=https://www.consul.io/docs/
After=network.target
[Service]
ExecStart=/usr/bin/consul agent -config-dir=/etc/consul.d
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure
LimitNOFILE=65536
[Install]
WantedBy=multi-user.target
EOT

  # Enable and start the Consul service
  sudo systemctl enable consul
  sudo systemctl start consul

else
   echo "Skipping Consul installation and configuration as INSTALL_CONSUL is set to false."
fi

if [ "$INSTALL_DANSWER" == "true" ]; then
  echo "Installing and configuring Danswer..."

  sudo mkdir -p /opt/danswer
  sudo chown -R nobody:nobody /opt/danswer
  sudo chmod -R 755 /opt/danswer

  # Install git
  sudo yum install -y git

  # Install Danswer
  cd /opt/danswer && sudo git clone https://github.com/gmsharpe/danswer.git .

  # create the directories for the nomad volumes
  sudo mkdir -p /var/nomad/volumes/danswer \
    && cd /var/nomad/volumes/danswer \
    && sudo mkdir -p db vespa nginx indexing_model_cache_huggingface model_cache_huggingface \
  
  cd /opt/danswer/deployment/nomad
  
  sudo nomad run danswer.nomad.hcl

  # copy the ngnix files
  sudo cp -r /home/ec2-user/danswer/deployment/data/nginx /var/nomad/volumes/danswer/nginx