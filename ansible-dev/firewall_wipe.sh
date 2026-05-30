#!/bin/bash
# firewall_wipe.sh - Purge PSTAT firewall configurations for a clean state

echo "Starting Firewall Wipe..."

# 1. Remove all PSTAT-related IPsets from the runtime
# Using a loop to avoid errors if sets don't exist
for set in management campus internal monitoring backup-network; do
    echo "Removing IPSet: $set"
    sudo ipset destroy $set 2>/dev/null || true
    sudo firewall-cmd --permanent --remove-ipset=$set 2>/dev/null || true
done

# 2. Clear all sources from the PSTAT zones
for zone in trusted internal public monitoring backup-network; do
    echo "Clearing sources for zone: $zone"
    # We use a loop to remove any source that starts with 'ipset:'
    sources=$(sudo firewall-cmd --zone=$zone --list-sources)
    for src in $sources; do
        if [[ $src == ipset:* ]]; then
            sudo firewall-cmd --permanent --zone=$zone --remove-source=$src
        fi
    done
done

# 3. Delete the XML configuration files
echo "Deleting IPSet XML files..."
sudo rm -f /etc/firewalld/ipsets/*.xml

# 4. Final reload to commit the void
sudo firewall-cmd --reload

echo "Wipe complete. System is now a blank slate."
