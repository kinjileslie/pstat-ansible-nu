#!/bin/bash
# firewall_rebuild.sh - Manually rebuild the PSTAT firewall identity

echo "Starting Manual Firewall Rebuild..."

# --- CONFIGURATION ---
# Management IPs (The Trusted Core)
MGMT_IPS=("169.231.230.113" "128.111.90.175" "169.231.235.191" "128.111.126.115" "128.111.90.54" "128.111.219.20")

# Campus Networks (The Internal Trust)
CAMPUS_NETS=("128.111.0.0/16" "169.229.0.0/16" "169.230.0.0/15" "169.232.0.0/15")

# ------------------------------------------------------------------------------
# STEP 1: Create IPSets directly in the kernel
# ------------------------------------------------------------------------------
echo "Step 1: Creating IPSets in Kernel..."

# Management Set
sudo ipset create management hash:ip
for ip in "${MGMT_IPS[@]}"; do
    sudo ipset add management $ip
done
echo "✓ Management set created."

# Campus Set
sudo ipset create campus hash:net
for net in "${CAMPUS_NETS[@]}"; do
    sudo ipset add campus $net
done
echo "✓ Campus set created."

# ------------------------------------------------------------------------------
# STEP 2: Link IPSets to Firewalld Zones (Permanent)
# ------------------------------------------------------------------------------
echo "Step 2: Linking IPSets to Zones..."

sudo firewall-cmd --permanent --zone=trusted --add-source=ipset:management
sudo firewall-cmd --permanent --zone=internal --add-source=ipset:campus

echo "✓ Zones linked to IPSets."

# ------------------------------------------------------------------------------
# STEP 3: Final Commit
# ------------------------------------------------------------------------------
echo "Step 3: Reloading Firewalld..."
sudo firewall-cmd --reload

echo "Rebuild complete. Checking state..."
echo "--------------------------------------------------"
echo "Trusted Zone Sources:"
sudo firewall-cmd --zone=trusted --list-sources
echo "Internal Zone Sources:"
sudo firewall-cmd --zone=internal --list-sources
echo "Kernel IPSet List:"
sudo ipset list | grep -E "Name:|Number of entries"
echo "--------------------------------------------------"
