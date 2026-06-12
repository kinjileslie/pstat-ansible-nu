#!/bin/bash

# List of hosts to probe
#HOSTS=("tom" "dick" "harry")
HOSTS=("pstat-web")
# Set output directory relative to the script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$SCRIPT_DIR/firewall_deep_dive"

mkdir -p "$OUTPUT_DIR"

echo "Starting Firewall Deep Dive (from sauza)..."

for HOST in "${HOSTS[@]}"; do
    echo "------------------------------------------------------------"
    echo "Analyzing: $HOST"
    echo "------------------------------------------------------------"
    
    # 1. RAW BYTE CHECK: Check for leading whitespace/BOM/encoding issues
    # we use 'od -c' to see exactly what the first 60 bytes are
    echo "Gathering raw bytes of public.xml..."
    ssh "$HOST" "sudo od -c /etc/firewalld/zones/public.xml | head -n 2" > "$OUTPUT_DIR/${HOST}_raw_bytes.txt" 2>&1
    
    # 2. FILE METADATA: Check timestamp and ownership
    echo "Checking file metadata..."
    ssh "$HOST" "sudo ls -la /etc/firewalld/zones/public.xml" > "$OUTPUT_DIR/${HOST}_metadata.txt" 2>&1
    
    # 3. CONTENT CHECK: Full content with line numbers and visible chars
    echo "Dumping full XML with visible chars..."
    ssh "$HOST" "sudo cat -A /etc/firewalld/zones/public.xml" > "$OUTPUT_DIR/${HOST}_full_xml.txt" 2>&1
    
    # 4. RELOAD ATTEMPT: Capture the exact failure
    echo "Testing reload..."
    ssh "$HOST" "sudo firewall-cmd --reload" > "$OUTPUT_DIR/${HOST}_reload_err.txt" 2>&1
    
    # 5. ZONE LIST: See what zones firewalld actually thinks exist
    echo "Listing zones..."
    ssh "$HOST" "sudo firewall-cmd --get-zones" > "$OUTPUT_DIR/${HOST}_zones_list.txt" 2>&1

    echo "Done with $HOST"
done

echo "------------------------------------------------------------"
echo "Deep dive complete. Results in $OUTPUT_DIR"
echo "Please share the contents of these files."
