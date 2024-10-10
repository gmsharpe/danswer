#!/bin/bash
set -euo pipefail

# Check if the correct argument is provided
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <consul_override_config_temp_file>"
  exit 1
fi

consul_override_config_temp_file=$1

# Check if the file exists
if [ ! -f "$consul_override_config_temp_file" ]; then
  echo "Error: Configuration file $consul_override_config_temp_file not found."
  exit 1
fi

# Load the config from the file
consul_override_config=$(cat "$consul_override_config_temp_file")

# Default settings
consul_config_file="/etc/consul.d/consul.hcl"
consul_config_dir="/etc/consul.d"
consul_env_vars="$consul_config_dir/consul.conf"
CONSUL_OVERRIDE_ENABLED=${CONSUL_OVERRIDE_ENABLED:-false}

echo "CONSUL_OVERRIDE_ENABLED is set to ${CONSUL_OVERRIDE_ENABLED}"

# Apply configuration based on override flag
if [ "${CONSUL_OVERRIDE_ENABLED}" = true ]; then
  if [ -z "${consul_override_config}" ]; then
    echo "Error: Override is enabled, but no Consul config is provided. Exiting."
    exit 1
  fi

  echo "Using custom Consul agent configuration."
  echo "${consul_override_config}" | sudo tee "$consul_config_file"

  sudo tee "${consul_env_vars}" > /dev/null <<ENVVARS
CONSUL_HTTP_ADDR=http://127.0.0.1:8500
ENVVARS

  echo "Updating file permissions"
  sudo chown consul:consul "$consul_config_file"
  sudo chmod 640 "$consul_config_file"
else
  echo "Using default Consul agent configuration."
  sudo tee "${consul_env_vars}" > /dev/null <<ENVVARS
FLAGS=-dev -ui -client 0.0.0.0
CONSUL_HTTP_ADDR=http://127.0.0.1:8500
ENVVARS
fi
