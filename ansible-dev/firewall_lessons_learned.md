# L2 Shield V2: Lessons Learned & Decision Log

## 1. The Transport Mystery (The "Lying" Template)
**Problem**: `ansible.builtin.template` reported success, but files on Tom, Dick, and Harry were not updating.
**Discovery**: Verified via 'Control Node' (Lloyd) that the module worked on fresh images.
**Root Cause**: Atomic rename failure on configured nodes.
**Decision**: Precede all zone templating with a direct `sudo rm -f` to clear the path and force a fresh write.

## 2. The XML Schema War
**Problem**: `firewall-cmd --reload` failed with `PARSE_ERROR: Unexpected element target` and `Unexpected element rich-rule`.
**Discovery**: The AlmaLinux 9 parser is strictly sequential and rejects non-standard tags.
**Implementation Choices**:
- **Target**: Moved `target="DROP"` from a child element to an attribute of the `<zone>` tag.
- **Rich Rules**: Changed `<rich-rule>` to `<rule>`.
- **Sequence**: Standardized on `<zone target="...">` $\rightarrow$ `<short>` $\rightarrow$ `<rule>`.
- **Syntax**: Ensured the XML declaration is at absolute character 0.

## 3. The Translation Gap (Firewalld $\rightarrow$ Nftables)
**Core Concept**: The networking stack follows a hierarchy: 
`Ansible` $\rightarrow$ `firewalld (Python Daemon)` $\rightarrow$ `nftables (Utility)` $\rightarrow$ `Netfilter (Kernel)`.
The "bugginess" we encountered is located in the **firewalld Python Daemon**, which translates high-level API calls into `nftables` commands.

### The "Wall of Text" Saga
**Problem**: `firewall-cmd --reload` failed with `INVALID_ZONE: not well-formed (invalid token): line X, column Y`.
**Discovery**:
1. **Whitespace Collapse**: Using `{%-` and `-%}` whitespace stripping in Jinja2 loops caused the XML rules to merge into one single, massive line. The `firewalld` parser has a buffer limit (approx. column 100) and crashes when a line is too long.
2. **The "Null" Trap**: Using `{% if rule.port is defined %}` returns `True` even if the value is `null` in YAML. This created empty tags like `<port port="" protocol=""/>` and illegal fragments like `</>`, which the parser rejects.
**Solution**:
- **Explicit Newlines**: Removed all whitespace stripping. Every `<rule>` must start on its own newline to satisfy the parser.
- **Truthiness Checks**: Switched from `is defined` to `rule.get('port')`. This ensures that `null` values are treated as `False` and the rule is skipped entirely.
- **Defensive Dictionary Access**: Used `.get()` for all capability lookups to avoid `AnsibleUndefinedVariable` crashes when optional keys (like `service`) are missing.
**Lesson**: When templating for strict XML parsers, prioritize vertical readability and explicit truthiness over Jinja "cleverness."

## 4. The "Dark Box" Verification (UDP & ICMP)
**Discovery**: Standard Nmap scans can be misleading for UDP.
- **`closed`**: Means the packet reached the host, but no service was listening (ICMP Port Unreachable returned).
- **`open|filtered`**: Often means the packet was silently dropped by the firewall.
**Verification Method**: Use `nc -ul <port>` on the server and `echo "test" | nc -u -w 1 <host> <port>` on the client to prove delivery.
**ICMP Special Case**: ICMP does not have "ports." Using a `<port>` tag for ICMP rules in XML causes the `firewalld` parser to silently ignore the rule. ICMP rules must omit the port tag.

## 5. Reverse SSH and Egress Risks
**Concept**: Reverse SSH tunnels (`ssh -R`) bypass ingress firewalls by establishing an outbound connection to a VPS.
**Risk**: If the VPS has `GatewayPorts yes` enabled, the tunnel becomes a public bridge, allowing anyone to hit the VPS and be piped directly into the server's SSH port.
**Defense**: This is an Application Layer (Layer 7) risk. The primary defenses are strict SSH key authentication (no passwords) and, in extreme cases, "Default Egress DROP" policies to prevent the "Call Home" connection from being established.

## 6. Network Management Authority
**Decision**: Bypass `firewalld`'s interface binding.
**Implementation**: Use `nmcli` to bind the interface UUID to the zone.
**Reasoning**: NetworkManager overrides `firewalld` configuration; modifying the NM profile is the only way to ensure persistence.

## 7. nftables Direct‑Rule Workaround
**Problem**: `firewall-cmd --direct` refuses all `--add-rule` commands on AlmaLinux 9 (firewalld 1.3.4). The daemon also owns the `inet firewalld` table, preventing external `nft` modifications.

**Solution**: Deploy an **independent nftables table** (`inet pstat_forward`) that hooks the `FORWARD` chain at priority `-10` (runs before firewalld’s `+10`). The table defines two IP sets (`pstat_mgmt_fwd` and `pstat_ts_fwd`) and a forward chain with a default `drop` policy, accepting only traffic from those sets and allowing established/related return traffic.

**Result**: Forwarding is now source‑aware, firewalld’s broken direct API is completely bypassed, and the security posture persists across firewalld reloads.

**Lesson**: When firewalld’s direct interface is broken, use a custom nftables table that runs at a higher priority to enforce forwarding policies. Persist the table via `/etc/nftables.d/` and load it after the final firewalld reload.

> **SUPERSEDED (2026-10-16):** See §8. We discovered a cleaner, *native* solution using firewalld **Policy Objects** that makes this nft shim unnecessary. The shim has been decommissioned on `seabastion`.

## 8. Native Firewalld Policy Forwarding (supersedes §7)
**Discovery**: Inter-interface forwarding **is** possible with native firewalld — via **Policy Objects** — on firewalld 1.3.4 / AlmaLinux 9, without `--direct` and without a custom nft table. The earlier conclusion that "policy forwarding is a dead end" was an **inspection error**, not a daemon limitation.

**Empirical findings (verified on the live host):**
1. A policy object compiles into `filter_FWD_policy_<name>` chains, dispatched from `filter_FORWARD_POLICIES_pre` by **interface pair** (`iifname … oifname … jump …`). It does **NOT** populate the zone `filter_FWD_<zone>_allow` chains — inspecting those made the policy look inert.
2. `target=ACCEPT` on a policy is **source-blind** (matches interface pair, accepts all). To be **source-aware**, use `target=CONTINUE` + a `source ipset=… accept` rich rule (lands in `filter_FWD_policy_<name>_allow`).
3. **Bidirectional** forwarding requires **two** policies (one per interface pair), because a policy is directional.
4. `ct state` is **invalid** in a rich rule on this version (`INVALID_RULE: unknown element ct`); the return path uses `target=ACCEPT` on the reverse policy (safe — egress zone scopes replies to the tailnet NIC).

**Ansible limitation**: The `ansible.posix.firewalld` module (1.6.2) has **no** `policy`/`ingress_zone`/`egress_zone` parameters and `target` is `required_by zone`. Policy objects must be driven by `firewall-cmd --permanent --policy` (shell), not the module. Use the module only for zone/interface/target, and `firewall-cmd` for policies.

**Final design**: zones (module) + IPSets (templated XML) + `mgmt-ssh` INPUT policy + `ts-to-build`/`build-to-ts` FORWARD policies (`firewall-cmd`) + persistent sysctl. No nft shim, no `--direct`.
