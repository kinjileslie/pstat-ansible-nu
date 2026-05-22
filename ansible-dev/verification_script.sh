#!/bin/bash

# PSTAT Baseline Verification Script
# Purpose: Verify that the cloud-init and initial ansible roles applied correctly.

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "--- Hardening Verification Report ---"

# 1. Check SSH Hardening
echo -n "Checking SSHD Hardening... "
SSH_CONFIG="/etc/ssh/sshd_config.d/hardening.conf"
if [ -f "$SSH_CONFIG" ] && grep -q "PasswordAuthentication no" "$SSH_CONFIG"; then
    echo -e "${GREEN}PASS${NC} (Config file exists and passwords disabled)"
else
    echo -e "${RED}FAIL${NC} (PasswordAuthentication not disabled in $SSH_CONFIG)"
fi

# 2. Check Sudoers (Wheel NOPASSWD)
echo -n "Checking Sudoers wheel-nopasswd... "
if [ -f "/etc/sudoers.d/wheel-nopasswd" ]; then
    echo -e "${GREEN}PASS${NC} (File exists)"
else
    echo -e "${RED}FAIL${NC} (Sudoers file missing)"
fi

# 3. Check Firewall Service & SSH Rule
echo -n "Checking Firewalld status... "
if systemctl is-active --quiet firewalld; then
    echo -e "${GREEN}PASS${NC} (Service running)"
else
    echo -e "${RED}FAIL${NC} (Service stopped)"
fi

echo -n "Checking Firewalld SSH rule... "
if firewall-cmd --list-services | grep -q "ssh"; then
    echo -e "${GREEN}PASS${NC} (SSH allowed)"
else
    echo -e "${RED}FAIL${NC} (SSH NOT allowed - Risk of lockout!)"
fi

# 4. Check Fail2Ban
echo -n "Checking Fail2Ban status... "
if systemctl is-active --quiet fail2ban; then
    echo -e "${GREEN}PASS${NC} (Service running)"
else
    echo -e "${RED}FAIL${NC} (Service stopped)"
fi

# 5. Check Ansible & Collections
echo -n "Checking Ansible-core... "
if command -v ansible >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC} (Installed)"
else
    echo -e "${RED}FAIL${NC} (Not installed)"
fi

echo -n "Checking ansible.posix collection... "
if ansible-galaxy collection list | grep -q "ansible.posix"; then
    echo -e "${GREEN}PASS${NC} (Installed)"
else
    echo -e "${RED}FAIL${NC} (Collection missing)"
fi

# 6. Check QEMU Guest Agent
echo -n "Checking QEMU Guest Agent... "
if systemctl is-active --quiet qemu-guest-agent; then
    echo -e "${GREEN}PASS${NC} (Running)"
else
    echo -e "${RED}FAIL${NC} (Not running)"
fi

echo "-------------------------------------"
