#!/bin/bash
set -x

# Based on https://github.com/hashicorp/guides-configuration/blob/master/vault/scripts/install-vault-systemd.sh

echo "Running `install-vault-systemd.sh`"

SYSTEMD_DIR="/etc/systemd/system"
echo "Installing systemd services for RHEL/CentOS"

sudo cp ./vault/init/systemd/vault.service ${SYSTEMD_DIR}/vault.service
sudo cp ./consul/init/systemd/consul_online.service ${SYSTEMD_DIR}/consul_online.service
sudo cp ./consul/init/systemd/consul_online.target ${SYSTEMD_DIR}/consul_online.target
sudo cp ./consul/init/systemd/consul_online.sh ${SYSTEMD_DIR}/consul_online.sh

sudo chmod 0664 ${SYSTEMD_DIR}/{vault*,consul*}

sudo systemctl unmask ${SYSTEMD_DIR}/consul_online.target

sudo systemctl enable consul
sudo systemctl start consul

sudo systemctl enable vault
sudo systemctl start vault

echo "Completed install of Vault"