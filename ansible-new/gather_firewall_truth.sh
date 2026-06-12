#!/bin/bash

# List of hosts to probe
HOSTS=("tom" "dick" "harry")
# Set output directory relative to the script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/firewall_debug_output"

mkdir -p "$OUTPUT_DIR"

echo "Starting Firewall Truth Gathering (from sauza)..."

for HOST in "${HOSTS[@]}"; do
    echo "------------------------------------------------------------"
    echo "Gathering data from: $HOST"
    echo "------------------------------------------------------------"
    
    # 1. File Metadata and First 5 lines with visible characters
    echo "Checking /etc/firewalld/zones/public.xml..."
    ssh "$HOST" "sudo ls -l /etc/firewalld/zones/public.xml && sudo cat -A /etc/firewalld/zones/public.xml | head -n 5" > "$OUTPUT_DIR/${HOST}_public_xml.txt" 2>&1
    
    # 2. Test Manual Reload and capture stderr
    echo "Testing firewall-cmd --reload..."
    ssh "$HOST" "sudo firewall-cmd --reload" > "$OUTPUT_DIR/${HOST}_reload_output.txt" 2>&1
    
    # 3. Kernel Truth: nftables ruleset
    echo "Dumping nftables ruleset..."
    ssh "$HOST" "sudo nft list ruleset" > "$OUTPUT_DIR/${HOST}_nft_full.txt" 2>&1
    
    # 4. Specific check for the public allow chain
    echo "Filtering for public allow chain..."
    ssh "$HOST" "sudo nft list ruleset | grep -A 20 'filter_IN_public_allow'" > "$OUTPUT_DIR/${HOST}_public_chain.txt" 2>&1

    echo "Done with $HOST"
done

echo "------------------------------------------------------------"
echo "All data gathered in $OUTPUT_DIR"
echo "Please provide the contents of these files."
