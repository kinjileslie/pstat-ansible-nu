# Layer 3: The Fortress - LVM & Compliance Roadmap

## 📌 Current State
- **Baseline Verified**: Nodes `forger16`, `forger19`, and `forger20` have successfully passed L1, L2, and L3 mandatory foundations.
- **Symmetry**: The L1 $\rightarrow$ L2 $\rightarrow$ L3 pipeline is now fully reproducible on fresh VMs.
- **Checkpoint**: L2 snapshots are established as the "Known Good" recovery points before L3 application.

## 🎯 Objectives
The goal of Layer 3 is to move from a generic VM disk layout to a structured, compliant, and resilient storage architecture using LVM on the secondary disk (`vdb`).

### 🛠️ Current Status (as of 2026-05-26)
- [x] **Symmetry Achieved**: L1 and L2 verified across the fleet.
- [x] **LVM Deployment**: `role_lvm_fortress` implemented and verified (v1.2 "Alta Model" with `/local` absorber).
- [x] **Boot Stability**: Implemented `nofail` mount options and `systemd` overrides for `auditd` to prevent Emergency Mode boot-loops.
- [x] **XFS Accounting**: `role_xfs_quotas` fully operational (uquota, gquota) on `/local` and `/tmp`.
- [x] **Path Standardization**: Standardized on `/dev/mapper/` device paths for LVM to ensure mount reliability.
- [ ] **Compliance Overlay**: Deploy `RedHatOfficial.rhel9_cui` as an optional "Compliance Toggle" for CUI-specific nodes.

### 🚧 Architectural Decisions
- **The "Absorber" Model**: Shifted from a specific "Workhorse" volume to a generalized `/local` volume. All user-driven data (homes, containers, scratch) is consolidated here to protect the root partition.
- **Foundation vs. Policy**: 
    - **Foundation (Mandatory)**: LVM layout and XFS Quotas.
    - **Policy (Optional)**: CUI Hardening. This allows for a "Standard" vs "Hardened" node build.
- **Boot Safety**: Use of `nofail` in `fstab` ensures the system always boots to a reachable SSH state, even if a secondary volume fails.

### 1. Storage Architecture (The Three-Tier Model)
- **Disk 1 (`vda`)**: OS, `/boot`, `/boot/efi`.
- **Disk 2 (`vdb`)**: The "Fortress" LVM Volume Group.
- **Disk 3**: (Future) Network-attached storage/NFS/Ceph.

### 2. The LVM "Fortress" Layout (`vdb`)
#### A. Compliance & Security LVs
- `/var/log/audit`: Dedicated space for audit logs.
- `/var/log`: General system logs.
- `/tmp`: Temporary filesystem isolation.

#### B. The `/local` Absorber
- **Purpose**: The primary landing zone for all non-OS data.
- **Implementation**: A large LV (70GB) that hosts `/local/home` and container storage.
- **Goal**: Prevent disk exhaustion on the root partition.

### 3. Implementation Path
1. **LVM Orchestration**: Create VG and LVs (Audit, Logs, Tmp, Local).
2. **Stability Layer**: Apply `nofail` and `systemd` overrides for `auditd`.
3. **Accounting Layer**: Enable kernel `rootflags` and apply XFS quotas to `/local` and `/tmp`.
4. **Compliance Overlay**: (Optional) Run `RedHatOfficial.rhel9_cui` as a final hardening step.

## 🛡️ Risk Mitigation
- **Snapshot-First**: No L3 changes are applied without a verified L2 snapshot. 
- **Snapshot Recovery Warning**: Restoring to the L2 snapshot wipes all LVM partitioning on `vdb`.
- **The `nofail` Safety Net**: All LVM mounts use `nofail` to ensure the node remains reachable via SSH during troubleshooting.
