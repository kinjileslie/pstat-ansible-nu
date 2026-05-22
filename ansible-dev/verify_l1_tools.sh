#!/bin/bash
# Verification script for role_base_tools

TOOLS=(
    "net-tools"
    "tree"
    "bind-utils"
    "wget"
    "curl"
    "git"
    "lsof"
    "lshw"
    "yum-utils"
    "lsscsi"
    "tcpdump"
    "nmap"
    "rsync"
    "vim-enhanced"
    "parted"
)

echo "--- Verifying Base Tools Installation ---"
echo "Host: $(hostname)"
echo "Date: $(date)"
echo "----------------------------------------"

FAILED=0

for tool in "${TOOLS[@]}"; do
    if rpm -q "$tool" > /dev/null 2>&1; then
        echo "✅ $tool: INSTALLED"
    else
        echo "❌ $tool: MISSING"
        FAILED=$((FAILED + 1))
    fi
done

echo "----------------------------------------"
if [ $FAILED -eq 0 ]; then
    echo "RESULT: All tools verified successfully! 🎉"
    exit 0
else
    echo "RESULT: $FAILED tool(s) are missing. ⚠️"
    exit 1
fi
