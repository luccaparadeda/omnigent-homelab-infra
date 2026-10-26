#!/usr/bin/env bash
set -euo pipefail

sudo apt-get clean
sudo find /var/log -type f -exec truncate -s 0 {} \;
sudo rm -rf /tmp/* /var/tmp/* /var/lib/cloud/instances/*
sudo cloud-init clean --logs --seed
sudo truncate -s 0 /etc/machine-id
sudo rm -f /var/lib/dbus/machine-id
# Clones must generate their own server identity on first boot.
sudo rm -f /etc/ssh/ssh_host_*
rm -f "$HOME/.bash_history"
