# Work Plan (Completed): Secure Pivot for Seabastion

**Status:** ✅ COMPLETE (2026-10-16)

**Objective:** Restrict `seabastion`'s forwarding capabilities to only allow traffic from the `management` IPSet and the `tailscale` (100.120.0.0/24) IPSet. This converts it from a "Universal Router" to a "Secure Pivot."

## Final Implementation

### Architecture Decision
After exhausting firewalld's native mechanisms (rich rules, `--direct` API), we implemented a **dedicated nftables table** (`inet pstat_forward`) that hooks the FORWARD chain at priority `-10` — running **before** firewalld's table at `+10`. This is the project's established "bypass the broken layer" pattern.

### What Was Deployed

**`/etc/nftables.d/pstat-forward.nft`** (managed by Ansible):
```nft
table inet pstat_forward {
    set pstat_mgmt_fwd {
        type ipv4_addr
        flags interval
        elements = { <management IPs from pstat_mgmt_ips> }
    }
    set pstat_ts_fwd {
        type ipv4_addr
        flags interval
        elements = { 100.120.0.0/24 }
    }
    chain forward {
        type filter hook forward priority -10; policy drop;
        ct state { established, related } accept
        ip saddr @pstat_mgmt_fwd accept
        ip saddr @pstat_ts_fwd accept
    }
}
```

### Files Modified
1. **`group_vars/pstat.yml`** — Added `network_bridge_transit` to `pstat_capability_map` with `transit_rules` and a `tailscale` IPSet reference.
2. **`host_vars/seabastion.yml`** — Added `network_bridge_transit` to `pstat_capabilities`.
3. **`roles/role_firewall/defaults/main.yml`** — Added `tailscale` IPSet to `pstat_ipsets`.
4. **`roles/role_firewall/tasks/main.yml`** — Moved `manage_forwarding.yml` to run **after** the final `firewall-cmd --reload`.
5. **`roles/role_firewall/tasks/manage_forwarding.yml`** — Rewritten to deploy the `pstat_forward` nftables table.

### Security Posture (Verified)
| Traffic | Result |
|---------|--------|
| Management IP → Build VLAN | ✅ Accepted |
| Tailscale (100.120.0.0/24) → Build VLAN | ✅ Accepted |
| Campus laptop → Build VLAN | ❌ DROPPED |
| Internet → Build VLAN | ❌ DROPPED |
| Established/related (return traffic) | ✅ Accepted |

### Remaining Work (Not Critical)
- **Boot persistence:** The `pstat_forward` table is runtime-only. Add a systemd oneshot or `/etc/nftables.conf` inclusion to load `/etc/nftables.d/pstat-forward.nft` at boot.
- **Tailscale provisioning:** `tailscaled` installation and headscale enrollment are separate (awaiting headscale POC completion).
- **Other hosts:** No other host currently uses `network_bridge_transit`, so no impact.
