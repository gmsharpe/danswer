#!/bin/bash
#set -x

SYSTEMD_DIR="/etc/systemd/system"
echo "Installing systemd services for RHEL/CentOS"

sudo cp ./nomad/init/systemd/nomad.service $SYSTEMD_DIR/nomad.service
sudo cp ./consul/init/systemd/consul-online.service $SYSTEMD_DIR/consul-online.service
sudo cp ./consul/init/systemd/consul-online.target $SYSTEMD_DIR/consul-online.target
sudo cp ./consul/init/systemd/consul-online.sh $SYSTEMD_DIR/consul-online.sh

sudo chmod 0664 ${SYSTEMD_DIR}/{nomad*,consul*}

sudo systemctl enable nomad
sudo systemctl start nomad
