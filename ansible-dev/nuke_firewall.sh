#!/bin/bash
# nuke_firewall.sh - Full "nuke and rebuild" for the PSTAT Secure Pivot firewall.
#
# Supersedes the older firewall_wipe.sh. This resets firewalld + the nft shim
# to a verified blank slate, and (optionally) re-applies the whole config via
# the Ansible L2 playbook.
#
# USAGE:
#   nuke_firewall.sh                 # nuke only (blank slate), no rebuild
#   nuke_firewall.sh --dry-run       # show what WOULD be nuked; don't change anything
#   nuke_firewall.sh --rebuild       # nuke, then re-apply via deploy_l2_shield_v2.yml
#   nuke_firewall.sh --host <name>   # target host for --rebuild (default: seabastion)
#
# WHERE TO RUN:
#   - The NUCe steps run ON THE TARGET HOST (as root, e.g. via the console).
#   - The REBUILD step (if requested) runs FROM THE ANSIBLE CONTROL NODE
#     (flanker) and needs the ansible-new/ dir + inventory reachable.
#
#   In practice: run this script on the control node with --rebuild, OR
#   copy the "NUKE" section to the console. The script detects whether it
#   can reach the host over SSH and adapts.

set -uo pipefail

# ----------------------------------------------------------------------------
# Defaults
# ----------------------------------------------------------------------------
DRY_RUN=0
REBUILD=0
HOST="seabastion"
ANSIBLE_DIR="$(cd "$(dirname "$0")/../ansible-new" 2>/dev/null && pwd)"
INVENTORY="inventories/pstat.ini"
PLAYBOOK="deploy_l2_shield_v2.yml"

# ----------------------------------------------------------------------------
# Parse args
# ----------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)  DRY_RUN=1; shift ;;
        --rebuild)  REBUILD=1; shift ;;
        --host)     HOST="$2"; shift 2 ;;
        -h|--help)
            grep '^# ' "$0" | sed 's/^# //' | head -20
            exit 0 ;;
        *) echo "Unknown arg: $1 (see --help)"; exit 2 ;;
    esac
done

# ----------------------------------------------------------------------------
# Colours (only if stdout is a TTY)
# ----------------------------------------------------------------------------
if [[ -t 1 ]]; then
    R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[1m'; N=$'\033[0m'
else
    R=""; G=""; Y=""; B=""; N=""
fi
log()  { echo "${B}==>${N} $*"; }
ok()   { echo "${G}  [OK]${N} $*"; }
warn() { echo "${Y}  [WARN]${N} $*"; }
fail() { echo "${R}  [FAIL]${N} $*"; }
run()  {  # run a command, honouring --dry-run
    if [[ $DRY_RUN -eq 1 ]]; then
        echo "  ${Y}[dry-run]${N} $*"
    else
        eval "$@"
    fi
}

# ----------------------------------------------------------------------------
# Root check (nuke steps need root)
# ----------------------------------------------------------------------------
if [[ $EUID -ne 0 ]] && [[ $DRY_RUN -eq 0 ]]; then
    warn "Not running as root — nuke steps require root. Re-run with sudo, or use --dry-run."
fi

log "PSTAT Firewall Nuke  (host target: ${HOST})  dry-run=${DRY_RUN}  rebuild=${REBUILD}"

# ----------------------------------------------------------------------------
# PHASE 1 — NUKE (runs on the target host as root)
# ----------------------------------------------------------------------------
log "PHASE 1: Nuke (blank slate)"

# 1. Stop firewalld (clears all runtime state, unblocks console access)
run "systemctl stop firewalld"

# 2. Wipe ALL permanent firewalld config (zones, ipsets, policies, interfaces)
for d in zones ipsets policies interfaces; do
    run "rm -f /etc/firewalld/${d}/*.xml"
done

# 3. Remove the persisted nft shim file
run "rm -f /etc/nftables.d/pstat-forward.nft"

# 4. Remove the persistent sysctl file
run "rm -f /etc/sysctl.d/99-pstat-routing.conf"

# 5. Delete leftover nft tables (shim + firewalld) from the kernel
run "nft delete table inet pstat_forward 2>/dev/null || true"
run "nft delete table inet firewalld     2>/dev/null || true"

# 6. Reset the runtime kernel forwarding value
run "sysctl -w net.ipv4.ip_forward=0"

# 7. Remove firewalld auto-backup files (all four dirs)
for d in zones ipsets policies interfaces; do
    run "rm -f /etc/firewalld/${d}/*.xml.old"
done

# 8. Verify blank slate
log "PHASE 1 verify: confirming blank slate"
if [[ $DRY_RUN -eq 1 ]]; then
    echo "  ${Y}[dry-run]${N} skipping verification"
else
    fw_state=$(systemctl is-active firewalld 2>/dev/null)
    [[ "$fw_state" == "inactive" ]] && ok "firewalld: $fw_state" || fail "firewalld: $fw_state (expected inactive)"

    xml_count=$(find /etc/firewalld -name '*.xml*' 2>/dev/null | wc -l)
    [[ "$xml_count" -eq 0 ]] && ok "firewalld config: 0 *.xml* files" || fail "firewalld config: $xml_count *.xml* files remain"

    if nft list table inet firewalld >/dev/null 2>&1; then
        fail "inet firewalld table still present"
    else
        ok "inet firewalld table: absent"
    fi

    fwd=$(sysctl -n net.ipv4.ip_forward 2>/dev/null)
    [[ "$fwd" == "0" ]] && ok "net.ipv4.ip_forward: $fwd" || warn "net.ipv4.ip_forward: $fwd (expected 0)"

    if [[ -e /etc/nftables.d/pstat-forward.nft ]]; then
        fail "nft shim file still present"
    else
        ok "nft shim file: absent"
    fi
fi

# ----------------------------------------------------------------------------
# PHASE 2 — REBUILD (optional; runs the Ansible L2 playbook)
# ----------------------------------------------------------------------------
if [[ $REBUILD -eq 1 ]]; then
    log "PHASE 2: Rebuild via Ansible (host: ${HOST})"

    if [[ $DRY_RUN -eq 1 ]]; then
        echo "  ${Y}[dry-run]${N} would run: cd ${ANSIBLE_DIR} && ansible-playbook -i ${INVENTORY} ${PLAYBOOK} --limit ${HOST}"
        echo ""
        echo "Nu (blank-slate) plan complete. Nothing was changed."
        exit 0
    fi

    if [[ ! -d "$ANSIBLE_DIR" ]]; then
        fail "Ansible dir not found: ${ANSIBLE_DIR} (this script must live in ansible-dev/ with ansible-new/ as a sibling)"
        exit 3
    fi

    (
        cd "$ANSIBLE_DIR" || exit 3
        echo "  Running: ansible-playbook -i ${INVENTORY} ${PLAYBOOK} --limit ${HOST}"
        ansible-playbook -i "$INVENTORY" "$PLAYBOOK" --limit "$HOST"
    )
    rc=$?

    if [[ $rc -eq 0 ]]; then
        ok "Ansible rebuild succeeded (rc=0)"
        log "POST-REBUILD VERIFY"
        # Quick functional check of the pivot dispatch rules
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "root@${HOST}" \
             "nft list chain inet firewalld filter_FORWARD_POLICIES_pre" 2>/dev/null | grep -qE "ts-to-build|build-to-ts"; then
            ok "Pivot dispatch rules present on ${HOST}"
        else
            warn "Could not verify pivot over SSH — confirm manually on the console:"
            echo "     nft list chain inet firewalld filter_FORWARD_POLICIES_pre"
        fi
    else
        fail "Ansible rebuild failed (rc=${rc}) — check output above; console access may be needed"
    fi
else
    echo ""
    log "Nuke complete. Host is a verified blank slate."
    echo "  To rebuild:   ${B}nuke_firewall.sh --rebuild --host ${HOST}${N}"
    echo "  Or manually:  cd ../ansible-new && ansible-playbook -i inventories/pstat.ini ${PLAYBOOK} --limit ${HOST}"
fi
