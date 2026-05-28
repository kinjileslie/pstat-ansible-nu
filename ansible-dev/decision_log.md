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
