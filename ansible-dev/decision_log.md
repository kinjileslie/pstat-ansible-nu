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
