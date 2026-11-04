# Firewall Refactor — `seabastion` (COMPLETE: native firewalld pivot)

**Status:** ✅ IMPLEMENTED & PROVEN (2026-10-16)

This document records the **final, verified** architecture. It replaces the
earlier "tentative plan" (which proposed a firewalld-only model via the
`ansible.posix.firewalld` module — see §8 for why that was wrong).

---

## 1. Goal
An **Ansible-managed, source-aware firewall** on `seabastion` that:
- Allows SSH (and Cockpit) to the host from `management` and `tailscale` IPs.
- Forwards traffic **between** the tailnet and the build subnet, source-aware.
- Denies everything else (default-DROP).
- Uses **native firewalld** (no custom nft shim, no `firewall-cmd --direct`).

---

## 2. Final Architecture (verified by hand on the live host)

### Zones (all `target=DROP`)
| Zone | Interface | Purpose |
|------|-----------|---------|
| `public`   | `eth0`       | Internet/edge; default-deny |
| `internal` | `eth1`       | Build subnet `10.2.16.0/21`; default-deny |
| `trusted`  | `tailscale0` | Tailnet `100.120.0.0/24`; default-deny |

### IPSets (templated XML, single source of truth)
- `management` (hash:ip) — the admin IP list
- `campus`, `monitoring`, `backup-network`
- `tailscale` (hash:net) — `100.120.0.0/24`

### Policies (firewalld Policy Objects — the key to native forwarding)
| Policy | Ingress → Egress | Target | Rule | Effect |
|--------|------------------|--------|------|--------|
| `mgmt-ssh`    | `ANY` → `HOST`     | `CONTINUE` | `source ipset=management service ssh accept`<br>`source ipset=management service cockpit accept`<br>`source ipset=tailscale service ssh accept` | Source-aware admin SSH/Cockpit **to the host** |
| `ts-to-build` | `trusted` → `internal` | `CONTINUE` | `source ipset=tailscale accept` | **Tailnet → build** forwarding, source-aware |
| `build-to-ts` | `internal` → `trusted` | `ACCEPT` | *(none)* | **Build → tailnet** return path (zone-scoped) |

### Kernel (persistent sysctl)
```
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
```

---

## 3. Why this works (the hard-won findings)

These were **empirically verified** on firewalld 1.3.4 / AlmaLinux 9 and are
the reason the earlier attempts failed:

1. **A Policy object does NOT populate the zone `filter_FWD_<zone>_allow`
   chains.** It compiles into its own `filter_FWD_policy_<name>` chains,
   dispatched from `filter_FORWARD_POLICIES_pre` by **interface pair**.
   *Lesson: when a policy appears to "do nothing," inspect
   `nft list chain inet firewalld filter_FORWARD_POLICIES_pre`, not the
   zone allow chains.*

2. **`target=ACCEPT` on a policy is source-blind.** It matches the interface
   pair and accepts unconditionally. To be **source-aware**, set
   `target=CONTINUE` and add a `source ipset=... accept` rich rule — that rule
   lands in `filter_FWD_policy_<name>_allow`.

3. **Bidirectional forwarding needs TWO policies.** A policy is directional
   (one ingress/egress zone pair). `ts-to-build` (tailnet→build) and
   `build-to-ts` (build→tailnet) are separate objects.

4. **`ct state` is NOT valid in a firewalld rich rule** on this version
   (`Error: INVALID_RULE: unknown element ct`). The return path therefore
   uses `target=ACCEPT` on the reverse policy, which is safe because
   `egress=trusted` restricts replies to the tailnet NIC and only
   tailnet-initiated sessions can exist on that path.

5. **`firewall-cmd --direct --add-rule` is broken** on this build (usage
   error for every call) — the reason the original nft shim existed. The
   policy-object model makes the shim unnecessary.

---

## 4. What was removed
- `table inet pstat_forward` (the priority −10 nft shim) — deleted.
- `/etc/nftables.d/pstat-forward.nft` — deleted (Ansible removes it).
- `manage_forwarding.yml` (raw nft shim task) — replaced by
  `manage_forward_policy.yml`.
- The old "both eth0/eth1 → public" NIC binding — replaced by per-interface
  bindings (eth0→public, eth1→internal, tailscale0→trusted).

---

## 5. Ansible implementation
| File | Role |
|------|------|
| `roles/role_firewall/tasks/main.yml` | Orchestrates: zones (XML) → ipsets → `mgmt-ssh` policy → **interface binding (`ansible.posix.firewalld`)** → forwarding policies → sysctl → shim cleanup → reload |
| `roles/role_firewall/tasks/manage_forward_policy.yml` | Creates `ts-to-build` + `build-to-ts` policies via `firewall-cmd --permanent --policy`, applies source-aware rich rule, verifies `filter_FORWARD_POLICIES_pre` |
| `roles/role_firewall/tasks/manage_sysctl.yml` | Persists `ip_forward` + `rp_filter` via `ansible.posix.sysctl` |
| `roles/role_firewall/defaults/main.yml` | Adds `pstat_forwarding_policies`; per-policy `target`; NIC→zone map now host-overridable |
| `host_vars/seabastion.yml` | Binds eth0→public, eth1→internal, tailscale0→trusted; declares `network_bridge_transit` |
| `roles/role_firewall/tasks/manage_policy.yml` | Now respects per-policy `target` (was hard-coded CONTINUE) |

**Hybrid module choice (deliberate):**
- Zones/interface binding → `ansible.posix.firewalld` (clean, idempotent, supported).
- Policy objects + policy rich rules → `firewall-cmd` shell (the **only** way — see §8).
- IPSets → templated XML (proven against the strict parser).
- sysctl → `ansible.posix.sysctl`.

---

## 6. Verification (run after a successful playbook)
```bash
firewall-cmd --get-active-zones
# expect: internal→eth1, public→eth0, trusted→tailscale0

firewall-cmd --info-policy ts-to-build
firewall-cmd --info-policy build-to-ts

nft list chain inet firewalld filter_FORWARD_POLICIES_pre
# expect BOTH dispatch rules:
#   iifname "tailscale0" oifname "eth1" jump filter_FWD_policy_ts-to-build
#   iifname "eth1" oifname "tailscale0" jump filter_FWD_policy_build-to-ts

nft list chain inet firewalld filter_FWD_policy_ts-to-build_allow
# expect: ip saddr @tailscale accept

nft list table inet pstat_forward
# expect: "No such file or directory" (shim gone)

sysctl -n net.ipv4.ip_forward net.ipv4.conf.all.rp_filter
# expect: 1 1
```
**Functional:** from a tailnet node, `ssh kinji@100.120.0.1` (bastion) works;
from a *public* IP, SSH is denied. (Subnet routing to other build-net hosts is
a separate tailscale `--advertise-routes`/`--accept-routes` concern, not a
firewall change.)

---

## 7. Rollback (if the pivot misbehaves)
```bash
# Restore the old nft shim (file may still exist pre-cleanup):
nft -f /etc/nftables.d/pstat-forward.nft 2>/dev/null || \
  echo "shim file already removed — re-run the old manage_forwarding.yml from git"
```
Console access + a spare seabastion image is the ultimate fallback.

---

## 8. Why the original "pure `ansible.posix.firewalld`" plan was wrong
Gemini's spec (and the first draft of this doc) used:
```yaml
ansible.posix.firewalld:
    policy: ts-to-build
    ingress_zone: trusted
    egress_zone: internal
```
**Those parameters do not exist.** Inspecting the installed module
(`ansible.posix` 1.6.2, `plugins/modules/firewalld.py`) `argument_spec`:
```
icmp_block, service, protocol, port, port_forward, rich_rule, zone,
immediate, source, permanent, state, timeout, interface, forward,
masquerade, offline, target
```
No `policy` / `ingress_zone` / `egress_zone`. `target` is `required_by zone`.
So the module **cannot create or configure policy objects at all** — it is
zone-scoped only. Policy forwarding *is* a native firewalld capability
(proven in §3), but it must be driven by `firewall-cmd` (Option A), not the
Ansible module. This is why the final implementation is a **hybrid**: the
module where it's supported, `firewall-cmd` where it isn't.
