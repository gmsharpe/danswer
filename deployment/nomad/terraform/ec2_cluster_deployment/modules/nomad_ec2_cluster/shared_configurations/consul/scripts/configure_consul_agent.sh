#!/bin/bash

consul_override_config_temp_file=$1

# Use the config files
consul_override_config=$(cat "$consul_override_config_temp_file")

# Default is 'dev' mode.  Do NOT run in production.
consul_config_file="/etc/consul.d/consul.hcl"
consul_config_default=""
consul_config_dir=/etc/consul.d
consul_env_vars=$consul_config_dir/consul.conf

DO_OVERRIDE_CONFIG=${DO_OVERRIDE_CONFIG:-false}

echo "DO_OVERRIDE_CONFIG is set to ${DO_OVERRIDE_CONFIG}"

# If override is true, use the custom config if set; otherwise, use the default config file
if [ "${DO_OVERRIDE_CONFIG}" = true ]; then
  echo "Use custom Consul agent config (consul_override_config): \n ${consul_override_config} \n"
  consul_config=${consul_override_config}
else
  echo "Use default Consul agent config"
  consul_config=${consul_config_default}
fi

if [ "${DO_OVERRIDE_CONFIG}" = true ]; then
  if [ ${#consul_config} -eq 0 ]; then
    echo "Error: DO_OVERRIDE_CONFIG is set to true, but no consul_config is provided. Exiting."
    exit 1
  else
    cat <<CONFIG | sudo tee $consul_config_file
${consul_config}
CONFIG

    sudo tee ${consul_env_vars} > /dev/null <<ENVVARS
CONSUL_HTTP_ADDR=http://127.0.0.1:8500
ENVVARS

    echo "Update Consul configuration override file permissions"
    sudo chown consul:consul $consul_config_file
  fi
else
    echo "consul_override_config is not set. Starting Consul in -dev mode."

    sudo tee ${consul_env_vars} > /dev/null <<ENVVARS
FLAGS=-dev -ui -client 0.0.0.0
CONSUL_HTTP_ADDR=http://127.0.0.1:8500
ENVVARS

fi