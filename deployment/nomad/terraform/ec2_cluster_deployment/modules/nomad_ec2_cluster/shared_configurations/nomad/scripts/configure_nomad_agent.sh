#!/bin/bash

nomad_override_config_temp_file=$1
nomad_override_config=$(cat "$nomad_override_config_temp_file")

# Set the default values for the Nomad configuration
ip_address=${IP_ADDRESS:-"10.0.1.10"}
server_count=${SERVER_COUNT:-"1"}
vault_ip=${VAULT_IP:-"10.0.1.10"}
token_for_nomad=${TOKEN_FOR_NOMAD:-}
consul_ip_address=${CONSUL_IP_ADDRESS:-}
task_token_ttl=${TASK_TOKEN_TTL:-"1h"}

node_pool=${NODE_POOL:-"default"}
server_ips=${SERVER_IPS:-'["10.0.1.10"]'}


nomad_config_default=""
nomad_config_file="/etc/nomad.d/nomad.hcl"
nomad_config_dir="/etc/nomad.d"
nomad_env_vars=$nomad_config_dir/nomad.conf

NOMAD_OVERRIDE_ENABLED=${NOMAD_OVERRIDE_ENABLED:-false}

# If override is true, use the custom config if set; otherwise, use the default config file
if [ ${NOMAD_OVERRIDE_ENABLED} == true ]; then
  echo "Use custom nomad agent config (nomad_override_config)"
  nomad_config=${nomad_override_config}
else
  echo "Use default nomad agent config"
  nomad_config=${nomad_config_default}
fi

if [ ${NOMAD_OVERRIDE_ENABLED} == true ]; then
  if [ ${#nomad_config} -eq 0 ]; then
    echo "Error: NOMAD_OVERRIDE_ENABLED is set to true, but no nomad_config is provided. Exiting."
    exit 1
  else
    cat <<CONFIG | sudo tee $nomad_config_file
${nomad_config}
CONFIG

  sudo tee ${nomad_env_vars} > /dev/null <<ENVVARS
NOMAD_ADDR=http://127.0.0.1:4646
ENVVARS

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