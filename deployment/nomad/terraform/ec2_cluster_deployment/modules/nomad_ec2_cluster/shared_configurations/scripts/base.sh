#!/bin/bash
set -x

# This script is intended to be run as the first part of setting up a new instance (i.e. Nomad, Consul or Vault)
# Similar in purpose to this `base.sh` script from Hashicorp's guides-configuration repo:
#     * https://github.com/hashicorp/guides-configuration/blob/master/shared/scripts/base.sh

sudo yum update -y
sudo yum install -y yum-utils shadow-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo