#!/bin/bash

usage() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -vault_token        Vault token for authentication (required)"
    echo "  -vault_server_ip    IP address of the Vault server (required)"
    echo
    echo "Example:"
    echo "  $0 -vault_token your-vault-token -vault_server_ip 192.168.1.10"
    exit 1
}

# Parse the named arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -vault_token)
      vault_token="$2"
      shift 2
      ;;
    -vault_server_ip)
      vault_server_ip="$2"
      shift 2
      ;;
    *)
      echo "Invalid argument: $1"
      usage
      ;;
  esac
done

echo -e "\nRunning add_vault_config.sh"
echo "# =========================================="
echo "# === Adding Vault Config to Nomad Agent ==="
echo -e "# ==========================================\n"

work_dir=${work_dir:-"nomad/config"}

vault_server_ip=${vault_server_ip:-"10.0.1.10"}
vault_policy_name=${vault_policy_name:-"nomad-cluster"}
# Set the Vault role name if not already set
vault_role_name=${vault_role_name:-"nomad-cluster"}
vault_id=${vault_id:-"nomad-cluster"}
task_token_ttl=${task_token_ttl:-"1h"}
vault_policy_template=${vault_policy_template:-"$work_dir/default_vault_policy_template.hcl"}

if [ -z "$vault_token" ]; then
  vault_token = $(grep 'Initial Root Token' /opt/vault/data/vault-init-output.txt | awk '{print $NF}')
  if [ -z "$vault_token" ]; then
    echo "Error: Vault token not provided and not found in /opt/vault/data/vault-init-output.txt."
    exit 1
  fi
fi

export VAULT_ADDR="http://$vault_server_ip:8200"
export VAULT_TOKEN=$vault_token

# setup nomad_vault_token
# If you have a token for Nomad to access Vault, configure the token permissions in Vault
echo "Setting up Vault policies and token for Nomad..."

# Check if the 'nomad-cluster' policy already exists
if ! vault policy list | grep -q "^${vault_policy_name}$"; then
  # Configure a policy for Nomad in Vault
  envsubst < "$vault_policy_template" | vault policy write "$vault_policy_name" -
  echo "Policy '${vault_policy_name}' has been created."
else
  echo "Policy '${vault_policy_name}' already exists. Skipping policy creation."
fi

# Check if the token role already exists
if ! vault list auth/token/roles | grep -q "^${vault_role_name}$"; then
  vault write auth/token/roles/${vault_role_name} policy=nomad-cluster period=2h
  echo "Token role '${vault_role_name}' has been created."
else
  echo "Token role '${vault_role_name}' already exists. Skipping role creation."
fi


# Create a token with the Nomad policy
nomad_vault_token=$(vault token create -policy=$vault_policy_name -role $vault_role_name -field token -period "2h")

if [ -z "$nomad_vault_token" ]; then
  echo "Error creating Vault token."
  exit 1
fi

echo "Vault token for Nomad: $nomad_vault_token"

# save nomad token elsewhere (e.g. SSM Parameter Store)
echo "Storing Nomad Vault token in SSM Parameter Store..."
aws ssm put-parameter --name "/${vault_id}/${vault_role_name}/token" --value "$nomad_vault_token" --type "String" --overwrite # --type "SecureString"
if [ $? -ne 0 ]; then
  echo "Warning: error storing Nomad Vault token in SSM Parameter Store."
fi

echo "Adding Vault block to Nomad configuration..."
# add Vault configuration to Nomad configuration
cat <<EOT >> /etc/nomad.d/nomad.hcl
vault {
  enabled = true
  address = "http://$vault_server_ip:8200"  # Vault server address
  token   = "${nomad_vault_token}"         # Token with access to Vault policies
  create_from_role = "${vault_role_name}"   # Role to create tokens
  role = "${vault_role_name}"
  task_token_ttl = "${task_token_ttl}" # e.g. "1h"
}
EOT
