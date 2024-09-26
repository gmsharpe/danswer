#!/bin/bash


echo "Start Nomad in -dev mode"
sudo tee ${NOMAD_ENV_VARS} > /dev/null <<ENVVARS
FLAGS=-bind 0.0.0.0 -dev
ENVVARS

echo "Set Nomad profile script"
sudo tee ${NOMAD_PROFILE_SCRIPT} > /dev/null <<PROFILE
export NOMAD_ADDR=http://127.0.0.1:4646
PROFILE