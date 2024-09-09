#!/bin/bash

# clone the repository to the home directory and run this script
# sudo git clone https://github.com/gmsharpe/danswer.git

# create the directories for the nomad volumes
sudo mkdir -p /var/nomad/volumes/danswer
cd /var/nomad/volumes/danswer && sudo mkdir -p db_volume vespa_volume

# copy the ngnix files
sudo cp -r /home/ec2-user/danswer/data/nginx /var/nomad/volumes/danswer/nginx