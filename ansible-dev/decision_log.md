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
