#!/bin/bash

# useful for older machines with broadcom wifi cards that struggle with NetworkManager
# also a good fallback if you want to quickly connect to a network without dealing with NetworkManager

INTERFACE="wlp3s0b1"
CONF="/etc/wpa_supplicant/college.conf"

# 1. Dependency Checks (Is everything installed?)
for tool in wpa_supplicant wpa_cli dhclient iw; do
    if ! command -v $tool &> /dev/null; then
        echo "❌ Error: $tool is not installed. Run: sudo apt install $tool"
        exit 1
    fi
done

# 2. Config Check (Does the file exist?)
if [ ! -f "$CONF" ]; then
    echo "❌ Error: $CONF not found. Please create it first."
    exit 1
fi

# 3. Clean Slate
echo "🧹 Cleaning up..."
sudo killall -9 wpa_supplicant dhclient 2>/dev/null
sudo rm -rf /var/run/wpa_supplicant/$INTERFACE 2>/dev/null

# 4. Setup Hardware (MacBook stability fix)
sudo ip link set $INTERFACE up
sudo iw dev $INTERFACE set power_save off

# 5. Start Authentication
echo "🔐 Authenticating $INTERFACE..."
sudo wpa_supplicant -i $INTERFACE -c $CONF -B

# 6. Status Loop
for i in {1..15}; do
    STATUS=$(sudo wpa_cli -i $INTERFACE status | grep "wpa_state" | cut -d= -f2)
    if [ "$STATUS" == "COMPLETED" ]; then
        echo "✅ Authenticated!"
        break
    fi
    [ $i -eq 15 ] && echo "❌ Auth Timeout." && exit 1
    sleep 1
done

# 7. Request IP
echo "🌐 Getting IP address..."
sudo dhclient -v -nw $INTERFACE

# 8. Final Verification
sleep 2
IP=$(ip addr show $INTERFACE | grep "inet " | awk '{print $2}' | cut -d/ -f1)
if [ ! -z "$IP" ]; then
    echo "----------------------------------------"
    echo "🚀 TEDDY IS ONLINE! IP: $IP"
    echo "----------------------------------------"
else
    echo "❌ DHCP failed. Try: sudo dhclient -v $INTERFACE"
fi