# Ansible-Nu: PSTAT Infrastructure Orchestration

## 🎯 Project Goal
Modernize Ansible configuration for PSTAT nodes (AlmaLinux 9) using an atomic, layered architecture (The Layer Cake), resolving SSH persistence, implementing a flexible identity model, and ensuring system stability through resource isolation and secure firewall policies.

## 🏗️ Architecture: The Layer Cake
We utilize a tiered deployment strategy to ensure a deterministic system state:
- **Layer 1 (System Base)**: OS updates, NTP, repos, core tools, and basic users.
- **Layer 2 (The Shield)**: The "Symmetry" Firewall model.
- **Layer 3 (Fortress & Compliance)**: LVM partitioning, XFS quotas, and CUI compliance hardening.
- **Layer 4 (Capabilities)**: Application-specific roles (Web Server, Network Bridge, PHP Engine, Resource Guardrails).

## 🛡️ The Symmetry Firewall Model (V3)
The firewall is designed as a "Dark Box" (Default DROP) with a "VIP Lane" for admins.

### 1. The Global Policy (Break-Glass)
A Global Policy `mgmt-ssh` provides a permanent administrative bypass. If the source IP is in the `management` IPSet, access is granted regardless of the zone's target.

### 2. The Symmetry Ceiling (Trust Hierarchy)
Security is managed via a "Ceiling" model. Each host has a `pstat_firewall_profile` which acts as the hard limit for all services:
- `access-level1-public`: (Value 1) Open to the world.
- `access-level2-internal`: (Value 2) Restricted to the Campus IPSet.
- `access-level3-restricted`: (Value 3) Restricted to the Management IPSet.

**Logic**: `Final Trust Level = MAX(Host Ceiling, Capability Request)`.
A "Campus" server cannot be made "Public" via a capability; it will always be clamped to the Campus level unless the host profile is reclassified.

### 3. Capability-Based Access
Functional access is granted via capabilities in `host_vars`.
- Example: `web_server_base` $\rightarrow$ Opens port 80/443.
- Example: `monitoring_target` $\rightarrow$ Opens port 10050.

## 🚀 Deployment Sequence
To provision a new node:
1. `deploy_l1_base.yml` $\rightarrow$ Basic OS and Connectivity.
2. `deploy_l2_shield_v2.yml` $\rightarrow$ Establish the security posture.
3. `deploy_l3.1_fortress.yml` $\rightarrow$ LVM partitions.
4. `deploy_l3.2_quotas.yml` $\rightarrow$ Disk quotas.
5. `deploy_l3.3_compliance.yml` $\rightarrow$ CUI Hardening.
6. `deploy_l4_system_apps.yml` $\rightarrow$ Add specific capabilities (Web, Bridge, PHP, etc.).

## 🗝️ Identity Model
- **Nu-Pink (Ed25519)**: Standard Administrative Build Key.
- **Nu-Gold (ECDSA)**: FIPS-compliant key used when `is_fips_enabled: true`.
- **Provisioning**: Cloud-Init provides initial trust to the management host.

## ⚠️ Critical Operational Notes
- **Connectivity**: Ansible is executed directly from `flanker.pstat` to the target hosts. The previous `ctrl1` jump-host strategy has been deprecated as it was inefficient and unstable.
- **Verification**: Firewall precedence and Symmetry levels have been verified on target VMs `tom` (Public), `dick` (Internal), and `harry` (Restricted).
- **LVM Mounts**: Always run `restorecon` on new LVM mounts to fix SELinux `unlabeled_t` issues that block `auditd`.
- **PHP-in-HTML**: For legacy sites using `.html` for PHP, the `php-fpm.conf` must have `.html` added to `security.limit_extensions`.
- **Firewall XML**: Templates must have the XML declaration at character 0 and follow the strict RHEL 9 sequence: `<zone target="...">` $\rightarrow$ `<short>` $\rightarrow$ `<rule>`.
