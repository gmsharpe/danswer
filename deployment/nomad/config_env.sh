#!/bin/bash

# install git
sudo yum install git -y

# clone the repository
sudo git clone https://github.com/gmsharpe/danswer.git

# create the directories for the nomad volumes
mkdir -p /var/nomad/volumes/danswer
cd /var/nomad/volumes/danswer && mkdir -p db_volume vespa_volume

# copy the ngnix files
cp -r /home/ec2-user/danswer/data/nginx /var/nomad/volumes/danswer/nginx