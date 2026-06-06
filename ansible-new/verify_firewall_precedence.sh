#!/bin/bash
echo "=== [1] Interface to Zone Binding ==="
nmcli -t connection show --active | grep ":eth0$" | cut -d: -f1 | xargs -I {} nmcli connection show {} | grep connection.zone

echo -e "\n=== [2] Active Firewalld Zones ==="
firewall-cmd --get-active-zones

echo -e "\n=== [3] Management IPSet Membership ==="
nft list set inet firewalld management | grep -E 'elements|type'

echo -e "\n=== [4] THE SMOKING GUN: filter_INPUT_ZONES Order ==="
# We use sudo because nft requires root
sudo nft list chain inet firewalld filter_INPUT_ZONES

echo -e "\n=== [5] Final Verdict ==="
if sudo nft list chain inet firewalld filter_INPUT_ZONES | grep -B 1 "filter_IN_internal" | grep -q "filter_IN_trusted"; then
    echo "RESULT: SUCCESS - Trusted/Management is evaluated before Internal/Campus."
else
    echo "RESULT: FAILURE - Precedence is still incorrect or rules are missing."
fi
