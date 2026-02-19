#!/bin/bash
if [[ "${EUID}" -ne 0 ]]; then
  echo "Error: please run as root (example: sudo bash ufw-setup.sh)"
  exit 1
fi

sudo ufw default deny incoming
sudo ufw default allow outgoing

# allow ssh
sudo ufw allow 22/tcp
sudo ufw limit 22/tcp
# allow http
sudo ufw allow 80/tcp
# allow https
sudo ufw allow 443/tcp

sudo ufw enable
sudo ufw status