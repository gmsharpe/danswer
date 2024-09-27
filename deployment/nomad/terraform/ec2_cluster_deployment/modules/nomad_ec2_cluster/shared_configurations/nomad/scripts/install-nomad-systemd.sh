#!/bin/bash

# todo - modify this to optionally expect a 'vault-token' file to be present before proceeding with nomad startup

systemd_dir="/etc/systemd/system"

sudo cp ./nomad/init/systemd/nomad.service $systemd_dir/nomad.service
sudo cp ./consul/init/systemd/consul-online.service $systemd_dir/consul-online.service
sudo cp ./consul/init/systemd/consul-online.target $systemd_dir/consul-online.target
sudo cp ./consul/init/systemd/consul-online.sh $systemd_dir/consul-online.sh

sudo chmod 0664 ${systemd_dir}/{nomad*,consul*}

sudo systemctl enable nomad
sudo systemctl start nomad
