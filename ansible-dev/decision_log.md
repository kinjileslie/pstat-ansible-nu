# PSTAT Project Decision Log

## Storage Architecture (L3)
**Date**: 2026-05-23
**Decision**: Adopt the "Alta Model" for local storage.
**Implementation**:
- Replace the "Workhorse" volume with a generalized `/local` absorber volume (70GB).
- Use a dedicated LVM volume for `/local` to isolate user data from the OS root (`vda`).
- Retain separate LVs for `/var/log/audit` and `/tmp` to satisfy CUI security benchmarks (`nodev,nosuid,noexec`).
- **Rationale**: Mirrors proven infrastructure on `alta` and `roble`, providing high-speed local scratch space while ensuring OS stability.

**Decision**: Use "Absolute Zero" Cloud-Init.
**Implementation**: Minimalist YAML providing only Bobby's key and `qemu-guest-agent`.
**Rationale**: Eliminates "silent boot failures" and moves all configuration into the audited Ansible pipeline.

**Decision**: LVM Recovery Strategy.
**Implementation**: Use "Replace Existing" snapshot restoration in Harvester.
**Lesson Learned**: LVM locks (especially `auditd`) can make `vgremove` fail. Restoring to a snapshot is the most efficient recovery path for LVM iterative testing.

**Decision**: LVM Device Pathing.
**Implementation**: Standardized on `/dev/mapper/vg_name-lv_name` instead of `/dev/vg_name/lv_name`.
**Rationale**: The mapper path is more consistent across different kernel versions and avoids "No route to host" or mount failures during boot in AlmaLinux 9.

**Decision**: XFS Quota Implementation (Accounting Mode).
**Implementation**: Enable `uquota,gquota,pquota` via `rootflags` in GRUB and `fstab` mount options.
**Rationale**: Provide full visibility into storage usage (User, Group, and Project) without imposing hard limits that could break researcher workflows.

**Decision**: Boot-Loop Prevention (L3).
**Implementation**: Added `nofail` to all LVM mount options and created a `systemd` override for `auditd.service` (`RequiresMountsFor=/var/log/audit`).
**Rationale**: Prevents the system from dropping into Emergency Maintenance mode if a secondary volume fails to mount, ensuring SSH access is always maintained.

## 2026-05-26: Decoupling Storage from Compliance and Redefining Layout

**Context**: The CUI compliance role was found to be coupled with the assumption of specific partitions. To provide flexibility for "semi-hardened" VMs and avoid forced partitioning, the storage and policy layers were decoupled.

**Decisions**:
1. **Decoupling**: LVM partitioning () is now a separate prerequisite from CUI hardening (). The hardening role now adapts to existing infrastructure rather than requiring it.
2. **CUI-Complete Layout**: Revised the  partition map to satisfy all CUI isolation requirements:
    - `/var/log/audit`: 5GB
    - `/var/log`: 10GB
    - `/tmp`: 10GB
    - `/var/tmp`: 5GB (New - closes CUI gap)
    - `/home`: 20GB (New - closes CUI gap / provides local fallback for NFS)
    - `/local`: 50GB (Adjusted - remains the "absorber" for user data)
3. **Identity Strategy**: Established the "Hybrid Home" model:
    - Static legal banner in `/etc/issue`.
    - Dynamic announcement board in `/etc/motd`.
    - NFS mount from `kingslanding.pstat` to `/home`, overlaying the local LVM partition.

**Impact**: Increases deployment flexibility and closes security audit gaps while maintaining the "Symmetry" goal.

## 2026-05-26: Decoupling Storage from Compliance and Redefining Layout

**Context**: The CUI compliance role was found to be coupled with the assumption of specific partitions. To provide flexibility for "semi-hardened" VMs and avoid forced partitioning, the storage and policy layers were decoupled.

**Decisions**:
1. **Decoupling**: LVM partitioning (`role_lvm_fortress`) is now a separate prerequisite from CUI hardening (`deploy_l3_compliance.yml`). The hardening role now adapts to existing infrastructure rather than requiring it.
2. **CUI-Complete Layout**: Revised the `vdb` partition map to satisfy all CUI isolation requirements:
    - `/var/log/audit`: 5GB
    - `/var/log`: 10GB
    - `/tmp`: 10GB
    - `/var/tmp`: 5GB (New - closes CUI gap)
    - `/home`: 20GB (New - closes CUI gap / provides local fallback for NFS)
    - `/local`: 50GB (Adjusted - remains the "absorber" for user data)
3. **Identity Strategy**: Established the "Hybrid Home" model:
    - Static legal banner in `/etc/issue`.
    - Dynamic announcement board in `/etc/motd`.
    - NFS mount from `kingslanding.pstat` to `/home`, overlaying the local LVM partition.

**Impact**: Increases deployment flexibility and closes security audit gaps while maintaining the "Symmetry" goal.

## 2026-05-28: The "Symmetry" of Connection Stability

**Context**: Encountered persistent `kex_exchange_identification: Connection reset by peer` and `Too many authentication failures` during L1 and L3 runs, even on fresh VMs.

**Diagnosis**: 
1. **Key Shuffling**: The SSH client was offering all available keys in the agent, triggering `MaxAuthTries` on the server.
2. **TCP Flood/Shunning**: The default Ansible "one connection per task" model created a burst of TCP sessions that triggered security appliances in the jump chain (`ctrl1` $\rightarrow$ VM), leading to temporary IP bans (the "Penalty Box").

**Decisions**:
1. **Identity Constraint**: Added `IdentitiesOnly=yes` and specified the identity file in `ansible.cfg` to stop key shuffling.
2. **Session Persistence**: Implemented `ControlMaster=auto` and `ControlPersist=60s` in `ansible.cfg`. This maintains a single persistent SSH tunnel for the entire playbook, bypassing the "rapid-fire" connection pattern.
3. **Execution Optimization**: Enabled `pipelining = True` to execute Python modules directly via `stdin`, removing the need to upload/delete temporary files to `/tmp`.

**Verification**:
- Verified `ControlMaster` via the existence of the Unix socket in `~/.ansible/cp/`.
- Verified `Symmetry` via `ansible-config dump` to ensure the engine is actually reading the local `ansible.cfg`.
- Verified via `sshd` logs that while `sudo` sessions remain atomic, the underlying SSH transport is now stable and persistent.

**Lesson Learned**: In complex jump chains and high-security target images, the "standard" Ansible connection model is too aggressive. Persistent connections (`ControlMaster`) and `pipelining` are mandatory for stability and to avoid being flagged as a security threat by intermediate firewalls.

## 2026-05-28: Resolving the CUI-Ed25519 Algorithm Conflict

**Context**: Applying the `RedHatOfficial.rhel9_cui` role disabled the `ssh-ed25519` signature algorithm in favor of stricter NIST-approved algorithms (RSA-SHA2-256/512). This resulted in immediate lockouts for all users using Ed25519 keys, even if the keys were correctly placed in `authorized_keys`.

**Decision**: Implement a "Symmetry Override" for SSH algorithms.
- **Action**: Created a specific configuration file `/etc/ssh/sshd_config.d/99-pstat-ed25519.conf` containing `PubkeyAcceptedAlgorithms +ssh-ed25519`.
- **Implementation**: This override is now applied in both `role_lvm_fortress` (as a proactive measure) and `deploy_l3_compliance.yml` (as a corrective measure).
- **Rationale**: While the CUI role pushes for strict NIST adherence, operational stability and the fleet-wide adoption of Ed25519 keys take precedence. We maintain the capability for full NIST 800-171 compliance but explicitly opt-out of the Ed25519 ban to avoid administrative lockouts.

**Lesson Learned**: Third-party security roles can introduce "destructive" changes to critical infrastructure (like SSH access). Always implement a "Restore Access" pattern that runs both BEFORE and AFTER high-risk hardening roles.

## 2026-05-28: Integrating Compliance Adjustments into the Atomic Pipeline

**Context**: The `RedHatOfficial.rhel9_cui` role disables `ssh-ed25519` by default to meet strict NIST guidelines. Because this role was run as a separate playbook, it created a "Lethal Gap" where the admin was locked out before a second "Adjustment" playbook could be run.

**Decision**: Merge the "Adjustment" logic directly into the `deploy_l3.3_compliance.yml` playbook as `post_tasks`.
- **Action**: Added a task to create `/etc/ssh/sshd_config.d/99-pstat-ed25519.conf` and restart `sshd` immediately after the CUI role completes.
- **Symmetry**: Included a final call to `role_provision_access` as a safety check.
- **Rationale**: Ensures that the system is never left in an inaccessible state. The "Lockdown" and "Restore" happen within the same persistent SSH session.

**Open To-Do**: Evaluate moving the "Deviation" (e.g., Ed25519 support) into `group_vars` for a policy-driven approach, allowing specific nodes to be truly NIST-compliant while others remain operationally accessible.

## 2026-05-28: The "MaxAuthTries" Trap in CUI-Hardened Nodes

**Context**: After applying the `RedHatOfficial.rhel9_cui` (L3.3) role, the target nodes become significantly more sensitive to SSH authentication attempts. Even with `ControlMaster` active, manual SSH attempts from Bobby to the targets frequently result in `Permission denied (publickey,...)` and subsequent lockouts.

**Diagnosis**:
1. **Strict Auth Limits**: The CUI role enforces a strict `MaxAuthTries` limit (likely 3).
2. **Identity Leaks**: If a user runs a manual `ssh` command without `-o IdentitiesOnly=yes` and a specific `-i` key, the SSH client offers every key in the agent. If the first 3 keys are incorrect, the server drops the connection immediately, regardless of whether the correct key was 4th in the list.
3. **The "Invisible" Ban**: Because the CUI role also tightens Fail2Ban and SSHD logging, these "authentication failures" can trigger security shunning faster than on a base L1/L2 node.

**Decision**: Mandate "Explicit Identity" for all manual and automated access to L3.3 nodes.
- **Requirement**: All connections MUST use: `ssh -o IdentitiesOnly=yes -i <path_to_pink_key> <target>`.
- **Implementation**: This is now codified in `ansible.cfg` for automation, but must be manually followed for all interactive shells.

**Lesson Learned**: Compliance is not just about the server configuration; it changes the "rules of engagement" for the administrator. A "Standard" SSH command that works on a Dev node will trigger a security lockout on a CUI-hardened node.

## 2026-05-28: Open Decision - L3 Dependency Mapping

**Context**: Currently, `deploy_l3.1_fortress.yml` (LVM) and `deploy_l3.2_quotas.yml` (XFS Quotas) are tightly coupled. L3.2 assumes the existence of the volumes created by L3.1. Conversely, `deploy_l3.3_compliance.yml` is independent and can be run on any node.

**Open Discussion**:
Should L3.2 be refactored to be "Infrastructure-Aware" (applying quotas only to existing partitions) to allow independent execution?

**Competing Strategies**:
1. **The Refactor**: Modify L3.2 to detect mount points and apply quotas conditionally. This maximizes modularity.
2. **The Logical Grouping**: Maintain the tight coupling but make it explicit in the documentation and naming that L3.1 and L3.2 form a single "Storage Suite," while L3.3 is a standalone "Security Overlay."

**Status**: PENDING. Decision deferred until fleet baseline is established.

## 2026-05-28: Transition to Capability-Based Configuration (The "Bridge" Model)

**Context**: The need for a "Bastion" node (`seabastion`) created a requirement for a unique network configuration (bridging the 1173 and 2176 VLANs) that differs from the rest of the fleet.

**Decision**: Reject "server-specific" roles in favor of a **Capability-Based Model**.
- **Approach**: Create a generic `role_network_bridge` that implements the "Core-and-Spoke" routing model (Default Gateway on the public interface, static routes for the internal target networks).
- **Trigger**: The role is applied conditionally based on a variable in `host_vars` (e.g., `is_network_bridge: true`).
- **Symmetry**: This allows any node in the fleet to be promoted to a "Bridge" node simply by updating its identity in `host_vars`, without modifying the underlying playbook logic.

**Rationale**: Maintains the "Layer Cake" architectural integrity. It avoids "special case" playbooks and ensures that the system remains scalable. Whether we have one bastion or twenty, the code remains identical.

**Implementation Plan**:
1. Develop `role_network_bridge`.
2. Integrate into the Layer 4 (Plumbing) pipeline.
3. Define `seabastion` identity in `host_vars`.

## 2026-05-29: The "Bridge" Routing and NetworkManager UUID Discovery

**Context**: Implementing a "Bastion" node (`seabastion`) required bridging two distinct VLANs (1173/Internal and 2176/Public). This introduced significant routing instability due to dual-DHCP default gateways and inconsistent NetworkManager profile naming.

**Technical Discoveries**:
1. **The Default Gateway Flip-Flop**: When two interfaces both provide a default gateway via DHCP, the kernel uses the one with the lowest metric. Manual deletion (`ip route del`) is temporary because the DHCP client restores the route upon lease renewal.
2. **NMCLI Profile Naming**: Relying on profile names (e.g., "Wired connection 1") is fragile. The only immutable identifier for a network profile is the UUID.
3. **The UUID Extraction Trap**: Modern `nmcli` versions have inconsistent support for the `-g uuid` flag. The most portable method to extract a UUID is: `nmcli connection show 'DEVICE' | grep 'connection.uuid' | awk '{print $2}'`.
4. **The "Tethered" Routing Requirement**: Even if a config file is correct, `nmcli` modifications may not immediately affect the kernel's active routing table. A `nmcli connection up` command is required to force a synchronization of the state.

**Decisions**:
1. **Core-and-Spoke Model**: 
    - Set the Public interface as the primary exit (default gateway).
    - Configure the Internal interface to `ipv4.ignore-auto-routes yes`.
    - Implement explicit static routes (e.g., `10.0.0.0/8`) for the internal fleet to ensure target traffic always uses the bridge.
2. **Capability-Based Orchestration**: Created `role_network_bridge` as a "Capability" role. It is applied conditionally via `host_vars` (`is_network_bridge: true`), allowing any node to be promoted to a bastion without changing the playbook structure.
3. **UUID Discovery Pattern**: The role now dynamically discovers the UUID of the target device at runtime, removing the need to hardcode fragile strings or UUIDs in `host_vars`.

**Lesson Learned**: In multi-homed environments, "Configuration" $\neq$ "State." Always force a connection refresh (`nmcli connection up`) after modifying routing parameters to ensure the kernel's active table matches the desired state.
