#!/bin/bash

# Default is 'dev' mode.  Do NOT run in production.
CONSUL_CONFIG_FILE="/etc/consul.d/consul.hcl"
CONSUL_CONFIG_DEFAULT=""
CONSUL_OVERRIDE_CONFIG=${CONSUL_OVERRIDE_CONFIG:-""}
DO_OVERRIDE_CONFIG=${DO_OVERRIDE_CONFIG:-false}

# If override is true, use the custom config if set; otherwise, use the default config file
if [ "$DO_OVERRIDE_CONFIG" == "true" ] && [ -n "$CONSUL_OVERRIDE_CONFIG" ]; then
  CONSUL_CONFIG=$CONSUL_OVERRIDE_CONFIG
else
  CONSUL_CONFIG=${CONSUL_CONFIG_FILE:-$CONSUL_CONFIG_DEFAULT}
fi

if [ ${DO_OVERRIDE_CONFIG} == true ] || [ ${DO_OVERRIDE_CONFIG} == 1 ]; then
  if [ ${#CONSUL_CONFIG} -eq 0 ]; then
    echo "Error: DO_OVERRIDE_CONFIG is set to true, but no CONSUL_CONFIG is provided. Exiting."
    exit 1
  else
      echo "Use custom Consul agent config"
      cat <<CONFIG | sudo tee $CONSUL_CONFIG_FILE
${CONSUL_CONFIG}
CONFIG

      sudo tee ${CONSUL_ENV_VARS} > /dev/null <<ENVVARS
CONSUL_HTTP_ADDR=http://127.0.0.1:8500
ENVVARS

    echo "Update Consul configuration override file permissions"
    sudo chown consul:consul $CONSUL_CONFIG_OVERRIDE_FILE
  fi
else
    echo "CONSUL_OVERRIDE_CONFIG is not set. Starting Consul in -dev mode."

    sudo tee ${CONSUL_ENV_VARS} > /dev/null <<ENVVARS
FLAGS=-dev -ui -client 0.0.0.0
CONSUL_HTTP_ADDR=http://127.0.0.1:8500
ENVVARS

fi