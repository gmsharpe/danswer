#!/bin/bash
#set -x

# Based on https://github.com/hashicorp/guides-configuration/blob/master/vault/scripts/install-vault-systemd.sh

echo "Running install-vault-systemd.sh"

systemd_dir="/etc/systemd/system"
echo "Installing systemd services for RHEL/CentOS"

sudo cp ./vault/init/systemd/vault.service $systemd_dir/vault.service
sudo cp ./consul/init/systemd/consul-online.service $systemd_dir/consul-online.service
sudo cp ./consul/init/systemd/consul-online.target $systemd_dir/consul-online.target
sudo cp ./consul/init/systemd/consul-online.sh $systemd_dir/consul-online.sh

sudo chmod 0664 $systemd_dir/{vault*,consul*}

sudo systemctl enable consul
sudo systemctl start consul

sudo systemctl enable vault
sudo systemctl start vault

echo "Completed install of Vault"