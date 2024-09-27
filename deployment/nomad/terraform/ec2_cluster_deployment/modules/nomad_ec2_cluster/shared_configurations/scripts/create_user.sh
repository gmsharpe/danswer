#!/bin/bash
# based on https://github.com/hashicorp/guides-configuration/blob/master/shared/scripts/setup-user.sh

USER="${1:-$USER}"
GROUP="${2:-$GROUP}"
HOME="${3:-$HOME}"
COMMENT="${4:-$COMMENT}"

create_user() {
  sudo /usr/sbin/groupadd --force --system ${GROUP}

  if ! getent passwd ${USER} >/dev/null ; then
    sudo /usr/sbin/adduser \
      --system \
      --gid ${GROUP} \
      --home ${HOME} \
      --no-create-home \
      --comment "${COMMENT}" \
      --shell /bin/false \
      ${USER}  >/dev/null
  fi
}

echo "Setting up user ${USER} with group ${GROUP} and home directory ${HOME}"

create_user

# Create & set permissions on HOME directory
sudo mkdir -pm 0755 ${HOME}
sudo chown -R ${USER}:${GROUP} ${HOME}
sudo chmod -R 0755 ${HOME}
