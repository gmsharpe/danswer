#!/bin/bash

PRIVATE_IP=$1
SERVER_IP=$2
IS_SERVER=$3

sudo yum -y install consul

# Configure Consul
cat <<EOT > /etc/consul.d/consul.hcl
data_dir = "/opt/consul"
bind_addr = "0.0.0.0"
client_addr = "0.0.0.0"
advertise_addr = "$PRIVATE_IP"
retry_join = ["$SERVER_IP"]
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