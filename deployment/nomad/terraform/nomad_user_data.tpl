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
bind_addr = "$PRIVATE_IP"
ui {
  enabled = true
}
EOT
fi
# used to have bind_addr = "0.0.0.0" in the client configuration

# Append the rest of the configuration
cat <<EOT >> /etc/nomad.d/nomad.hcl
client {
  enabled = true
  servers = ["${server_ip}"]

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


# Install and configure Consul if required
if [ "$INSTALL_CONSUL" == "true" ]; then
  sudo yum -y install consul

  # Configure Consul
  cat <<EOT > /etc/consul.d/consul.hcl
data_dir = "/opt/consul"
bind_addr = "$PRIVATE_IP"
retry_join = ["${server_ip}"]
EOT

  # Add server configuration if needed
  if [ "$IS_SERVER" == "true" ]; then
    cat <<EOT >> /etc/consul.d/consul.hcl
server = true
bootstrap_expect = 1
ui = true
EOT
  fi

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
if [ "$INSTALL_DANSWER" == "true" ]; then
  sudo mkdir -p /opt/danswer
  sudo chown -R nobody:nobody /opt/danswer
  sudo chmod -R 755 /opt/danswer

  sudo yum install -y git
  cd /opt/danswer && sudo git clone https://github.com/gmsharpe/danswer.git .

  # Create the directories for the Nomad volumes
  sudo mkdir -p /var/nomad/volumes/danswer/{db,vespa,nginx,indexing_model_cache_huggingface,model_cache_huggingface}
  
  cd /opt/danswer/deployment/nomad
  sudo nomad run danswer.nomad.hcl

  # Copy nginx files
  sudo cp -r /home/ec2-user/danswer/deployment/data/nginx /var/nomad/volumes/danswer/nginx
fi