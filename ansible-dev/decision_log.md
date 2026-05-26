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

**Decision**: XFS Quota Implementation (Accounting Mode).
**Implementation**: Enable `uquota,gquota,pquota` via GRUB and FSTAB.
**Rationale**: Provide visibility into storage hogs (UID/Project level) without imposing hard limits initially. This allows for auditing and "case-by-case" limit setting in the future.
