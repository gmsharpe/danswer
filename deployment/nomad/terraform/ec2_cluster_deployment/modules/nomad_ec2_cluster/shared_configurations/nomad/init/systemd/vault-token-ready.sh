#!/bin/bash

# todo - not currently used (10/14/24)

set -e
set -o pipefail

function waitForVaultToken() {
  local path=$1

  while [ ! -s "${path}" ] ; do
    echo "Waiting for file..."
    sleep 1
  done

  echo "File found."
}

waitForVaultToken "/secrets/nomad-server-token"
