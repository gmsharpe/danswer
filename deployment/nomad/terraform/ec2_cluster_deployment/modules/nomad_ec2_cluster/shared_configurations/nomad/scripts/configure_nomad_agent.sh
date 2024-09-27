#!/bin/bash

nomad_override_config_temp_file=$1
nomad_override_config=$(cat "$nomad_override_config_temp_file")

# Set the default values for the Nomad configuration
IP_ADDRESS=${IP_ADDRESS:-"10.0.1.10"}
SERVER_COUNT=${SERVER_COUNT:-"1"}
VAULT_IP=${VAULT_IP:-"10.0.1.10"}
TOKEN_FOR_NOMAD=${TOKEN_FOR_NOMAD:-}
CONSUL_IP_ADDRESS=${CONSUL_IP_ADDRESS:-}
TASK_TOKEN_TTL=${TASK_TOKEN_TTL:-"1h"}

NODE_POOL=${NODE_POOL:-"default"}
SERVER_IPS=${SERVER_IPS:-'["10.0.1.10"]'}


nomad_config_default=""
nomad_config_file="/etc/nomad.d/nomad.hcl"
nomad_config_dir="/etc/nomad.d"
nomad_env_vars=$nomad_config_dir/nomad.conf

DO_OVERRIDE_CONFIG=${DO_OVERRIDE_CONFIG:-false}

# If override is true, use the custom config if set; otherwise, use the default config file
if [ ${DO_OVERRIDE_CONFIG} == true ]; then
  echo "Use custom nomad agent config (nomad_override_config)"
  nomad_config=${nomad_override_config}
else
  echo "Use default nomad agent config"
  nomad_config=${nomad_config_default}
fi

if [ ${DO_OVERRIDE_CONFIG} == true ]; then
  if [ ${#nomad_config} -eq 0 ]; then
    echo "Error: DO_OVERRIDE_CONFIG is set to true, but no nomad_config is provided. Exiting."
    exit 1
  else
    cat <<CONFIG | sudo tee $nomad_config_file
${nomad_config}
CONFIG

  fi
else
  echo "nomad_override_config is not set. Starting Nomad in -dev mode."

  sudo tee ${nomad_env_vars} > /dev/null <<ENVVARS
FLAGS=-bind 0.0.0.0 -dev
NOMAD_ADDR=http://127.0.0.1:4646
ENVVARS

fi

  # todo - using https in production
  echo "Set Nomad profile script"
  sudo tee ${NOMAD_PROFILE_SCRIPT} > /dev/null <<PROFILE
export NOMAD_ADDR=http://127.0.0.1:4646
PROFILE