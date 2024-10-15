#!/bin/bash

DANSWER_VAULT_ROLE_NAME="danswer"
DANSWER_VAULT_POLICY_NAME="danswer"
NOMAD_VAULT_POLICY_NAME="nomad-cluster"

# ----------------------------------------
# 2. Create the 'danswer' policy
# ----------------------------------------
if ! vault policy list | grep -q "^${DANSWER_VAULT_POLICY_NAME}$"; then
  vault policy write danswer - <<EOT
# Policy for reading secret/data/danswer
path "secret/data/danswer" {
  capabilities = ["read"]
}
EOT
  echo "Policy '${DANSWER_VAULT_POLICY_NAME}' has been created."
else
  echo "Policy '${DANSWER_VAULT_POLICY_NAME}' already exists. Skipping policy creation."
fi

# ----------------------------------------
# 4. Create the token role for 'danswer-role'
# ----------------------------------------
if ! vault list auth/token/roles | grep -q "^${DANSWER_VAULT_ROLE_NAME}$"; then
  vault write auth/token/roles/${DANSWER_VAULT_ROLE_NAME} \
    allowed_policies="${DANSWER_VAULT_POLICY_NAME}" \
    period=2h
  echo "Token role '${DANSWER_VAULT_ROLE_NAME}' has been created."
else
  echo "Token role '${DANSWER_VAULT_ROLE_NAME}' already exists. Skipping role creation."
fi

# Create a child token with both policies
CHILD_TOKEN=$(sudo -u vault VAULT_TOKEN=${NOMAD_VAULT_TOKEN} vault token create \
  -policy=$NOMAD_VAULT_POLICY_NAME \
  -policy=$DANSWER_VAULT_POLICY_NAME \
  -period=2h \
  -orphan=false \
  -format=json | jq -r '.auth.client_token')

echo "Child token with '${NOMAD_VAULT_POLICY_NAME}' and '${DANSWER_VAULT_POLICY_NAME}' policies has been created."

# Update Nomad to use the child token
echo "${CHILD_TOKEN}" > /etc/nomad.d/vault_token
chmod 600 /etc/nomad.d/vault_token

echo "Vault token for Nomad has been updated with additional policies."