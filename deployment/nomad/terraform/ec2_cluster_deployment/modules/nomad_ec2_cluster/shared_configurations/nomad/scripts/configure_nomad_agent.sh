#!/bin/bash

# This script is designed to configure and start a Nomad agent, with support for optional override configurations.
# The script accepts several command-line arguments, including instance IPs and configuration files, and
# checks whether an override is enabled using the NOMAD_OVERRIDE_ENABLED environment variable. If true, it reads
# a custom configuration file and applies it. Otherwise, it defaults to the standard configuration.
#
# The script ensures required parameters are provided and supports both client and server modes for the Nomad agent.
# It also generates necessary environment variables for the Nomad agent and writes them to a profile script.
#
# Usage:
# ./script.sh -config_override_file <config_override_file_path> -instance_ip <IP> -is_server <true|false>
#             -is_client <true|false> -server_ip <IP>
#
# Example:
# ./script.sh -config_override_file /etc/nomad.d/override.hcl -instance_ip 10.0.1.100 -is_server true
#             -is_client false -server_ip 10.0.1.101
#
# Arguments:
#   -config_override_file: Path to the custom configuration file to override Nomad's default settings.
#   -instance_ip: The IP address of the instance where Nomad is running.
#   -is_server: Flag to determine if the node is running as a server (true) or not (false).
#   -is_client: Flag to determine if the node is running as a client (true) or not (false).
#   -server_ip: The IP address of the server to connect to when running in client mode.


set -euo pipefail

# Function to display usage
usage() {
  echo "Usage: $0 -config_override_file <config_override_file_path> -instance_ip <IP> -is_server <true|false> -is_client <true|false> -server_ip <IP>"
  exit 1
}

# Parse the remaining named arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -config_override_file)
      config_override_file="$2"
      shift 2
      ;;
    -instance_ip)
      instance_ip="$2"
      shift 2
      ;;
    -is_server)
      is_server="$2"
      shift 2
      ;;
    -is_client)
      is_client="$2"
      shift 2
      ;;
    -server_ip)
      server_ip="$2"
      shift 2
      ;;
    *)
      echo "Invalid argument: $1"
      usage
      ;;
  esac
done


# Check if NOMAD_OVERRIDE_ENABLED is true
if [[ "$NOMAD_OVERRIDE_ENABLED" == true ]]; then

  # Read the nomad_override_config file if it exists
  if [ -f "$nomad_override_config_file" ]; then
    nomad_override_config=$(cat "$config_override_file")
    echo "Nomad override configuration loaded from $config_override_file"
  else
    echo "Error: NOMAD_OVERRIDE_ENABLED is true, but $config_override_file does not exist."
    exit 1
  fi
else
  echo "NOMAD_OVERRIDE_ENABLED is false, skipping override configuration."
fi


# Check for required arguments
if [[ -z "$instance_ip" || -z "$server_ip" ]]; then
  echo "Error: instance_ip and server_ip are required."
  usage
fi

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
if [ "${NOMAD_OVERRIDE_ENABLED}" = true ]; then
  echo "Use custom nomad agent config (nomad_override_config)"
  nomad_config=${nomad_override_config}
else
  echo "Use default nomad agent config"
  nomad_config=${nomad_config_default}
fi

if [ "${NOMAD_OVERRIDE_ENABLED}" = true ]; then
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