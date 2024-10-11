#!/bin/bash

echo -e "\nRunning install_consul_systemd.sh"
echo "# ========================================="
echo "# ====    Configure Consul 'systemd'   ===="
echo -e "# =========================================\n"

SYSTEMD_DIR="/etc/systemd/system"
echo "Installing consul systemd service for RHEL/CentOS based systems"


# if configs are shared on the web, you can download them directly
# sudo curl --silent -Lo ${SYSTEMD_DIR}/consul.service ${CONFIG_URL}/shared_configurations/consul/init/systemd/consul.service

# let's assume that they are already downloaded in the ../init/systemd directory
sudo cp ./consul/init/systemd/consul.service $SYSTEMD_DIR/consul.service
sudo chmod 0664 $SYSTEMD_DIR/consul.service

sudo systemctl enable consul
sudo systemctl start consul

echo "Completed execution of install-consul-systemd.sh"