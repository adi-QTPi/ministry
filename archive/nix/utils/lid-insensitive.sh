#!/usr/bin/env bash

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)."
   exit 1
fi

LOGIND_CONF="/etc/systemd/logind.conf"

echo "Configuring $LOGIND_CONF for lid-closed operation..."

# Uncomment and set the variables to ignore
sed -i 's/^#HandleLidSwitch=.*/HandleLidSwitch=ignore/' "$LOGIND_CONF"
sed -i 's/^#HandleLidSwitchExternalPower=.*/HandleLidSwitch=ignore/' "$LOGIND_CONF"
sed -i 's/^#HandleLidSwitchDocked=.*/HandleLidSwitch=ignore/' "$LOGIND_CONF"

echo "Restarting systemd-logind to apply changes..."
systemctl restart systemd-logind

echo "Done! The system will now stay awake when the lid is closed."