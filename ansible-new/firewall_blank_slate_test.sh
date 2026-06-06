#!/bin/bash
set -e

echo "--- 1. NUKING EVERYTHING ---"
# Stop firewalld to clear runtime state
systemctl stop firewalld

# Wipe all permanent firewalld configs
rm -rf /etc/firewalld/zones/*.xml
rm -rf /etc/firewalld/ipsets/*.xml
rm -rf /etc/firewalld/policies/*.xml

# Start firewalld (starts in default 'public' zone)
systemctl start firewalld

echo "--- 2. CREATING THE MANAGEMENT IPSET ---"
# Use the API to create the set
firewall-cmd --permanent --new-ipset=management --type=hash:ip
firewall-cmd --permanent --ipset=management --add-entry=169.231.229.92

echo "--- 3. CREATING THE VIP POLICY (The 'Lane') ---"
# Create a policy that bypasses zones entirely
# Ingress: ANY -> Egress: HOST
firewall-cmd --permanent --new-policy=mgmt-ssh
firewall-cmd --permanent --policy=mgmt-ssh --add-ingress-zone=ANY
firewall-cmd --permanent --policy=mgmt-ssh --add-egress-zone=HOST
firewall-cmd --permanent --policy=mgmt-ssh --add-rich-rule='rule family="ipv4" source ipset="management" service name="ssh" accept'

echo "--- 4. LOCKING DOWN THE REST ---"
# Set the default zone to public and remove everything from it
firewall-cmd --set-default-zone=public
firewall-cmd --permanent --zone=public --remove-service=ssh
firewall-cmd --permanent --zone=public --remove-service=dhcpv6-client
firewall-cmd --permanent --zone=public --remove-service=cockpit

echo "--- 5. FINAL RELOAD ---"
firewall-cmd --reload

echo "--- VERIFICATION ---"
nft list chain inet firewalld filter_INPUT | grep "mgmt-ssh" || echo "Policy rule not found in filter_INPUT"
