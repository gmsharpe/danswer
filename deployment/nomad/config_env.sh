#!/bin/bash

# create the directories for the nomad volumes
mkdir -p /var/nomad/volumes/danswer
cd /var/nomad/volumes/danswer && mkdir -p db_volume vespa_volume