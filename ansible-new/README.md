# PSTAT Ansible Modernization
This project transforms the PSTAT node configuration from legacy monolithic roles into an atomic, layered architecture (The Layer Cake).

## 🚀 Quick Start for Operators

### 1. Baseline Deployment
To bring a new node up to the current L1/L2 baseline:

**Step A: Provisioning**
1. Deploy a new VM in Harvester using the latest `kinji_pstat.yml` (v1.2.0 "Absolute Zero").
2. Ensure a second volume is attached if LVM partitioning is required for the target environment.

**Step B: Configuration**
Run the full baseline integration test:
```bash
# Run the full baseline integration test
ansible-playbook -i inventories/pstat.ini test_l1_safe.yml --limit <hostname>
```

**Note on Provisioning**: New VMs are instantiated via Cloud-Init with a minimal "Absolute Zero" configuration. This provides only the **Build Key (KINJI ANSIBLE NU PINK)** and the `qemu-guest-agent`. All other users, keys, and packages are handled by the Ansible pipeline.
Alternatively, run specific layers:
- **Layer 1 (Base)**: `ansible-playbook -i inventories/pstat.ini deploy_l1_base.yml --limit <hostname>`
- **Layer 2 (Shield)**: Perimeter security. Now utilizes a **Profile-Based Firewall** model:
    - **Firewall Profiles**: Instead of individual toggles, nodes are assigned an access level in `host_vars` or via command-line overrides.
    - **Tiered Trust**: Policies are applied across four distinct zones: `management` (Fortress), `campus` (Internal), `public` (Wild), and functional zones (`monitoring`, `backup`).
    - **Access Gradient**:
        - `access-level1-public`: Open to the world (SSH enabled on public zone).
        - `access-level2-internal`: Open to Campus and Management.
        - `access-level3-restricted`: Open to Management only.
    - **Firewall Precedence (The "Campus Hijack")**: Identified a critical bug where overlapping IP ranges (e.g., Management IP within a larger Campus CIDR) cause `firewalld` to route traffic to the wrong zone. Because the `filter_INPUT_ZONES` chain evaluates rules linearly, the first match wins. To resolve this, the firewall must apply sources in a strict **Specific $\rightarrow$ General** order (Management $\rightarrow$ Campus) to ensure administrative access is not "hijacked" by broader network rules.
    - **Verification**: On AlmaLinux 9, `firewalld` uses native `nftables` sets. **DO NOT** use `ipset list` for verification; it will return empty results. Use `nft list set inet firewalld <set_name>` to verify IPSet population.
    - **Interface Authority**: NetworkManager profiles override `firewalld` zone assignments. Interfaces are bound to zones via `nmcli` using the connection UUID to ensure persistence.
    - **Identity-Based Access**: To prevent "VLAN Leaks," the firewall uses **Rich Rules** rather than general zone services for internal/trusted zones. This ensures that services (like SSH) are only accessible to IPs defined in the corresponding IPSet, regardless of which interface is used.
    - **Ad-Hoc Testing**: To test a stricter policy without modifying permanent variables:
      ```bash
      ansible-playbook -i inventories/pstat.ini deploy_l2_shield.yml --limit <hostname> -e "pstat_firewall_profile=access-level3-restricted"
      ```
      *Note: To revert to the baseline, simply run the playbook without the `-e` flag.*

### 2. Verifying Node State
To check if a node has been correctly provisioned and see the audit trail:

- **Check Audit Logs (The "Flight Recorder")**:
  `journalctl -t ansible-audit`
  (This shows a chronological list of every role successfully applied by Ansible).

- **Check Local Audit File**:
  `cat /var/log/ansible-provisioning/audit.log`

- **Check Firewall Policy Version**:
  `cat /etc/ansible/firewall_version.txt`

### 3. Layer 3, 4, and 5 (Advanced Deployment)
These layers follow an **Explicit Orchestration** model. Instead of hidden booleans, we use tags to specify exactly which "Capabilities" to install.

- **Layer 3 (Hardening)**: Optional high-security benchmarks. Now split into a sequenced pipeline:
    - **L3.1 Storage Foundation**: `deploy_l3.1_fortress.yml` (LVM partitioning).
    - **L3.2 Storage Accounting**: `deploy_l3.2_quotas.yml` (XFS accounting).
    - **L3.3 Security Policy**: `deploy_l3.3_compliance.yml` (CUI/STIG hardening via `RedHatOfficial.rhel9_cui` with integrated operational overrides).
    - *Note*: Policy can be applied without the Foundation for "semi-hardened" nodes.
    - **Connectivity**: Use the provided `ansible.cfg` (enabling `ControlMaster` and `pipelining`) to prevent network-level session resets and SSH lockouts during rapid task execution.

- **L4 (System Apps/Plumbing)**: Core infrastructure and capability-based configurations.
    - **Capability-Based Model**: Instead of server-specific roles, we use "Capability" roles (e.g., `role_network_bridge`) triggered by variables in `host_vars`.
    - **Registry**: See [CAPABILITIES.md](./CAPABILITIES.md) for a full list of available toggles and their required variables.
    - **Network Bridge (Core-and-Spoke)**: Solves the "Default Route Collision" during multi-interface provisioning.
        - **Persistence Strategy**: Uses `ipv4.route-metric` to anchor the Public Interface (`eth1`) as the primary gateway (Metric 50) while allowing the Internal Interface (`eth0`) to exist as a secondary (Metric 100+).
        - **Stability**: This ensures that even when DHCP pushes competing gateways, the "Management Path" remains open and survives reboots.
    - **Example**: A node marked as `is_network_bridge: true` will automatically receive the "Core-and-Spoke" routing configuration to bridge the 1173/2176 VLANs.
    - **Identity & Observability**: [TODO] Integrate LDAP/SSSD and Monitoring agents.
    - **Symmetry Cleanup**: [TODO] Remove the "Emergency" `PubkeyAcceptedAlgorithms` override from L3 compliance playbooks once the `is_fips_enabled` toggle is verified fleet-wide.
    - **L4-Tuning**: [TODO] Remove "Canary" debug prints from `role_network_bridge`.
    - **Identity Evolution (Key-Duo)**: [PLANNING] Transition from a single build key to a "Polyglot" identity model.
        - Use `ansible_ssh_private_key_file` in `host_vars` to dynamically select between Ed25519 (Nu-Pink) for standard nodes and ECDSA (Nu-Gold) for FIPS-compliant nodes.
        - This removes the bottleneck of a hardcoded key in `ansible.cfg` and prevents `MaxAuthTries` lockouts.
    - **Management Perimeter**: [TODO] Finalize and add all legitimate Bastion/Jump host IPs to the `management` IPSet.
    - **VLAN Trust Model**: [TODO] Decide on the trust level for the 1173 network (e.g., "Full Trust" vs. "Restricted Service Access") and implement in the firewall policy.
- **L5 (User Apps)**: Researcher tools (e.g., RStudio, Podman).

## 🗺️ Future Infrastructure Evolution
- **Migration Path**: Transition from legacy management hosts (bobby/race/ctrl1) to a new, self-provisioned jump host built using these scripts ("Dogfooding").
- **Identity Goal**: Shift from local identity management to centralized LDAP/SSSD.
- **Storage Challenge**: Evaluate alternatives to Longhorn for large user data volumes (500GB+), as Longhorn performance degrades at scale. Explore Ceph or other sovereign storage solutions.
- **Infrastructure Evolution**: 
    - **Migration Path**: Transition from legacy management hosts (bobby/race/ctrl1) to a new, self-provisioned jump host built using these scripts ("Dogfooding").
    - **Identity Goal**: Shift from local identity management to centralized LDAP/SSSD.
    - **Storage Challenge**: Evaluate alternatives to Longhorn for large user data volumes (500GB+), as Longhorn performance degrades at scale. Explore Ceph or other sovereign storage solutions.

**Usage**:
```bash
ansible-playbook -i inventories/pstat.ini deploy_l4_system_apps.yml --limit <hostname> --tags "splunk,pmm"
```
*Note: In the future, common tag sets can be defined in `group_vars` to automate the selection of standard capabilities.*

## 🛠 Maintenance Notes
- **Firewall Versioning**: A known technical debt item; the current `/etc/ansible/firewall_version.txt` is static. Future work is needed to implement a dynamic version string that reflects the active `pstat_firewall_profile` and policy version.
- **Agent Context**: For detailed technical history, decision logs, and AI-specific context, refer to [ansible_agent_context.txt](./ansible_agent_context.txt).
- **Adding Jump Hosts**: Add new IPs to `group_vars/pstat.yml` under `pstat_mgmt_ips`. This automatically updates both the Firewall and Fail2Ban ignore lists.
- **Customizing Roles**: All logic is atomic. To change a specific feature, edit the role in `roles/` and run the corresponding `deploy_lX.yml` playbook.
- **Key Path Fragility**: SSH private key paths in `pstat_identity_registry` are currently hardcoded to specific home directories. This will break if the management user or host changes. Needs transition to environment variables or project-relative paths.

### 📖 Engineer's Notebook: Troubleshooting the Shield

This project encountered significant "tooling friction" during the L2 rollout. To avoid the "Nuke and Pave" trap, follow this verification methodology when system tools appear to be "lying":

#### 1. The "Anti-Nuke" Protocol
Before deciding a tool is broken and pivoting to a custom implementation:
- **Strip Abstractions**: Stop using Ansible/scripts. Run commands manually in a raw shell.
- **Primitive Syntax**: Avoid modern flags (e.g., `nmcli -g` or `-f`). Use the most basic positional arguments and parse with `grep`/`cut`.
- **Verify State, Not Return Code**: A "success" from a daemon (`firewall-cmd`) only means the daemon updated its database. Always verify the **Kernel State** (the actual truth).

#### 2. The `nmcli` Compatibility Trap
- **The Issue**: Certain `nmcli` versions reject field-specific flags (`-g`, `-f`) as "invalid fields."
- **The Verified Path**: Use "Primitive Terse" mode for UUID discovery:
  `nmcli -t connection show --active | grep ":<iface>$" | cut -d: -f2`
- **The Binding Sequence**: `UUID Discovery` $\rightarrow$ `nmcli connection modify <UUID> connection.zone <zone>` $\rightarrow$ `nmcli connection up <UUID>`.

#### 3. Native `nftables` vs. Legacy `ipset`
- **The Issue**: Using `ipset list` on AlmaLinux 9 returns empty results, leading to the false conclusion that the firewall is not populated.
- **The Truth**: AlmaLinux 9 uses native `nftables` sets. The `ipset` binary talks to a different kernel module that `firewalld` no longer uses.
- **The Source of Truth**: Always use `nft list set inet firewalld <set_name>` to verify IPSet population.

#### 4. Interface Authority (The "Gravity" Problem)
- **The Issue**: `firewall-cmd --zone=... --add-interface=...` often fails to persist across reloads.
- **The Truth**: NetworkManager connection profiles (`.nmconnection`) override `firewalld` runtime assignments.
- **The Fix**: You must modify the specific **UUID** of the active NetworkManager profile to change the zone.

## 🚫 SSH Connection Stability (The "Idle Timeout" Mystery)

### The Problem
SSH sessions and sshfs mounts from `seabastion` to target nodes are disconnecting after ~45-60 minutes of idle time, despite `systemd-linger` and `ControlMaster` being enabled.

### Investigation Findings
1. **CUI `IdleActionSec=1800` NOT Applied**: The CUI role's `var_logind_session_timeout: '1800'` setting is not appearing in `/etc/systemd/logind.conf` on `seabastion`. Verified via `systemd-analyze cat-config`.
2. **SSH Keepalive Configurations**:
   - Server-side (`ClientAliveInterval 0`): Disabled (seabastion doesn't send keepalives)
   - Client-side (`ServerAliveInterval 300`): Enabled on `flanker` (client sends every 5 min)
3. **sshfs "Ghost Mounts"**: Mounts show as active in `df -h` but are actually dead after idle, confirming network-level disconnect.
4. **Timing**: Disconnects occur after ~45-60 minutes, which is not the default 10-minute timeout or the CUI 30-minute timeout.

### Root Cause
Network firewall/NAT device between `seabastion` and target nodes is killing idle TCP connections after ~45-60 minutes without sending graceful FIN packets. The client/server don't realize the connection is dead until they try to use it.

### Proposed Solution
Add server-side SSH keepalives to `seabastion`:
```bash
# Create keepalive config
echo "ClientAliveInterval 30" | sudo tee /etc/ssh/sshd_config.d/99-keepalive.conf
echo "ClientAliveCountMax 3" | sudo tee -a /etc/ssh/sshd_config.d/99-keepalive.conf

# Reload SSHD
sudo systemctl reload sshd

# Verify
sshd -T | grep -i clientalive
```

This makes `seabastion` send a keepalive packet every 30 seconds to the client, which the firewall will see as active traffic, preventing it from killing the connection.

### Status
Investigation complete, proposed solution documented. Awaiting implementation and verification.

## 🛡️ Compliance (Layer 3)
Compliance is managed as an optional overlay. Use `deploy_l3.3_compliance.yml` with the following tags:

| Tier | Tags | Description |
| :--- | :--- | :--- |
| **Baseline** | `low_complexity,no_reboot_needed` | Basic security tools & system baseline. |
| **Standard** | `low_complexity,medium_complexity,no_reboot_needed` | Tightens filesystem mounts and SSH timeouts. |
| **Strict** | `low_complexity,medium_complexity,high_complexity` | Full audit enforcement and restrictive network policies. |

### ⚙️ Architecture: Policy vs. Implementation (The "Symmetry" Model)
To maintain a balance between standard baseline and node-specific needs, we use a split-variable strategy for LVM and Hardening:

- **Role Defaults (`roles/*/defaults/main.yml`)**: Define the **Implementation Baseline**. (e.g., "Standard volume sizes: `/home` is 20GB, `/tmp` is 10GB"). This is the "blueprint."
- **Group Variables (`group_vars/pstat.yml`)**: Define the **Fleet Policy**. (e.g., "All volumes must use the `nofail` mount option"). This is the "governance."
- **Host Variables (`host_vars/*.yml`)**: Define **Exceptions**. (e.g., "This specific node needs 100GB for `/home`").

**Why?** This allows us to change the fleet-wide policy (e.g., updating mount options) in one place without touching the underlying structural blueprints of the roles.

### ⚠️ Operational Exceptions
To maintain system stability and support the "Layer Cake" architecture, the following CUI controls are explicitly disabled:

- **`subscription-manager`**: Not applicable to AlmaLinux.
- **`usbguard`**: Not applicable to Harvester VMs.
- **`fapolicyd`**: Disabled to prevent blocking of administrative scripts and custom binaries.
- **`authselect` / `pam_faillock`**: Deferred to Layer 4 (Identity) to prevent conflicts with LDAP/SSSD integration and avoid accidental lockouts.
- **`/var/log/audit` Mount Options**: Deferred to `role_lvm_fortress` and `role_xfs_quotas` to prevent overwriting `nofail` and custom XFS accounting options.
- **SELinux**: Set to `permissive` via CUI overrides to prevent administrative lockouts during initial rollout; will be evaluated for `enforcing` during L4 application testing.
- **SSH Daemon (`sshd`)**: All CUI-driven `sshd` modifications are disabled. All SSH hardening is centrally managed by `role_ssh_hardening` to ensure jump-chain stability.

**Current Status**: 
- **Baseline**: L1 and L2 fully operational.
- **Storage**: L3.1 (Fortress) and L3.2 (Quotas) verified on `reforger` fleet.
- **Compliance**: L3.3 (CUI) verified with operational Ed25519 override on `reforger-01` (now `seabastion`).
- **Plumbing**: L4 capability-based model implemented; `role_network_bridge` verified for multi-VLAN routing.
- **Open Items**:
    - Validate the overlap between low and medium complexity controls in the RHEL9 CUI role.
    - Update `role_lvm_fortress` to the "CUI-Complete" layout (add `/var/tmp` and `/home`).
    - Isolate `/var/tmp` via LVM to prevent root partition exhaustion (CUI requirement).
    - Execute the "Home Pivot" to `/local/home` to isolate user data from OS.
    - Implement legally compliant "California-grade" MOTD (Privacy/Monitoring warnings).
    - Implement a "Dynamic Announcement" system: 
        - Use `/etc/issue` as the static legal "No Trespassing" sign.
        - Use `/etc/motd` as a dynamic bulletin board for maintenance alerts, managed via a dedicated `deploy_announcement.yml` playbook.
    - **[OPEN] Firewall Policy Validation**: Perform rigorous cross-node testing for all three access levels (`public`, `internal`, `restricted`).
        - Verify `sauza` (Campus) can still access `internal` zone services.
        - Verify `flanker`/`ctrl1` (Management) can still access `trusted` zone services under all levels.
        - Confirm "Total Lockout" on `access-level3-restricted` for all non-management IPs.
    - **[OPEN] SSSD/KCM Log Error**: Resolve `sssd_kcm` failure to open `/var/log/sssd/sssd_kcm.log` (No such file or directory) on `seabastion`.
    - **[OPEN] SSH `maxauthtries` Recovery**: Document a reproducible method to clear an IP from the target's fail-list after hitting the maximum authentication attempts limit.
    - [ON HOLD] Layer 4 (Plumbing): Identity (LDAP/SSSD) and Monitoring.
