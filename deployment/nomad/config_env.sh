#!/bin/bash

# clone the repository to the home directory and run this script
# sudo git clone https://github.com/gmsharpe/danswer.git

# create the directories for the nomad volumes
sudo mkdir -p /var/nomad/volumes/danswer
cd /var/nomad/volumes/danswer && sudo mkdir -p db vespa nginx indexing_model_cache_huggingface model_cache_huggingface

# copy the ngnix files
sudo cp -r /home/ec2-user/danswer/data/nginx /var/nomad/volumes/danswer/nginx