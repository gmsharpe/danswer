#!/bin/bash
set -x

# Based on https://github.com/hashicorp/guides-configuration/blob/master/vault/scripts/install-vault-systemd.sh

echo "Running `install-vault-systemd.sh`"

SYSTEMD_DIR="/etc/systemd/system"
echo "Installing systemd services for RHEL/CentOS"

sudo cp ./vault/init/systemd/vault.service $SYSTEMD_DIR/vault.service
sudo cp ./consul/init/systemd/consul-online.service $SYSTEMD_DIR/consul-online.service
sudo cp ./consul/init/systemd/consul-online.target $SYSTEMD_DIR/consul-online.target
sudo cp ./consul/init/systemd/consul-online.sh $SYSTEMD_DIR/consul-online.sh

sudo chmod 0664 $SYSTEMD_DIR/{vault*,consul*}

sudo systemctl enable consul
sudo systemctl start consul

sudo systemctl enable vault
sudo systemctl start vault

echo "Completed install of Vault"