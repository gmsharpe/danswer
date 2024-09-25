#!/bin/bash

# Default is 'dev' mode.  Do NOT run in production.
CONSUL_CONFIG_FILE="/etc/consul.d/consul.hcl"
CONSUL_CONFIG_DEFAULT=""
OVERRIDE_CONSUL_CONFIG=${OVERRIDE_CONSUL_CONFIG:-false}
CONSUL_CONFIG=${CONSUL_CONFIG:-$CONSUL_CONFIG_DEFAULT}

if [ ${OVERRIDE_CONSUL_CONFIG} == true ] || [ ${OVERRIDE_CONSUL_CONFIG} == 1 ]; then
  if [ ${#CONSUL_CONFIG} -eq 0 ]; then
    echo "Error: OVERRIDE_CONSUL_CONFIG is set to true, but no CONSUL_CONFIG is provided. Exiting."
    exit 1
  else
      echo "Add custom Consul client override config"
      cat <<CONFIG | sudo tee $CONSUL_CONFIG_FILE
${CONSUL_CONFIG}
CONFIG

      sudo tee $${CONSUL_ENV_VARS} > /dev/null <<ENVVARS
CONSUL_HTTP_ADDR=http://127.0.0.1:8500
ENVVARS

    echo "Update Consul configuration override file permissions"
    sudo chown consul:consul $CONSUL_CONFIG_OVERRIDE_FILE
  fi
else
    echo "CONSUL_OVERRIDE_CONFIG is not set. Starting Consul in -dev mode."

    sudo tee $${CONSUL_ENV_VARS} > /dev/null <<ENVVARS
FLAGS=-dev -ui -client 0.0.0.0
CONSUL_HTTP_ADDR=http://127.0.0.1:8500
ENVVARS

fi