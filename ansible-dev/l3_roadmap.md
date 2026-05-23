# Layer 3: The Fortress - LVM & Compliance Roadmap

## 📌 Current State
- **Baseline Verified**: Nodes `forger16` and `forger17` have successfully passed L1 (System Base) and L2 (The Shield) using the "Absolute Zero" boot strategy.
- **Checkpoint**: Snapshots of `forger16` and `forger17` have been taken. These serve as the "Known Good" recovery points for L1/L2.

## 🎯 Objectives
The goal of Layer 3 is to move from a generic VM disk layout to a structured, compliant, and resilient storage architecture using LVM on the secondary disk (`vdb`).

### 1. Storage Architecture (The Three-Tier Model)
We are shifting from a single-disk OS model to a multi-disk functional split:
- **Disk 1 (`vda`)**: OS, `/boot`, `/boot/efi`.
- **Disk 2 (`vdb`)**: The "Fortress" LVM Volume Group.
- **Disk 3**: (Future) Network-attached storage/NFS/Ceph.

### 2. The LVM "Fortress" Layout (`vdb`)
We will implement a Volume Group (VG) on `vdb` to provide isolation and prevent system-wide failures due to disk exhaustion (Containment).

#### A. Compliance & Security LVs
Separate Logical Volumes (LVs) to ensure critical system functions are not disrupted by log floods or temp file explosions:
- `/var/log/audit`: Dedicated space for audit logs.
- `/var/log`: General system logs.
- `/tmp`: Temporary filesystem isolation.

#### B. The "Workhorse" Volume
- **Purpose**: Dedicated storage for rootless Podman containers.
- **Implementation**: A large LV mounted to a specific path, with a trigger script in `/etc/profile.d/` to symlink `~/.local/share/containers` for SSSD/LDAP users.
- **Goal**: Prevent researcher container images from exhausting `/home` or root (`/`) space.

#### C. Flex Space
- A portion of `vdb` will remain unallocated within the VG to allow for dynamic expansion of LVs without redeploying the VM.

### 3. Implementation Path
1. **Disk Preparation**: Use `parted` to initialize `vdb`.
2. **LVM Orchestration**:
    - Create Volume Group (VG).
    - Create Logical Volumes (LVs) for Audit, Logs, Tmp, and Workhorse.
    - Format with XFS (utilizing `xfs_quotas` for `/home` management).
3. **Mounting & Persistence**: Configure `/etc/fstab` and ensure mounts are active.
4. **The Symlink Trigger**: Deploy the `/etc/profile.d/` script to automate container storage redirection.
5. **Compliance Validation**: Deploy `RedHatOfficial.rhel9_cui` to verify the layout meets security benchmarks.

## 🛡️ Risk Mitigation
- **Snapshot-First**: No L3 changes are applied without a verified L2 snapshot.
- **Non-Destructive Testing**: Initial tests will focus on volume creation before moving to critical directory migration (e.g., moving `/var/log` to an LV).
