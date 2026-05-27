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

**Note on Provisioning**: New VMs are instantiated via Cloud-Init with a minimal "Absolute Zero" configuration. This provides only the **Provisioning Key (Bobby)** and the `qemu-guest-agent`. All other users, keys, and packages are handled by the Ansible pipeline.
Alternatively, run specific layers:
- **Layer 1 (Base)**: `ansible-playbook -i inventories/pstat.ini deploy_l1_base.yml --limit <hostname>`
- **Layer 2 (Shield)**: `ansible-playbook -i inventories/pstat.ini deploy_l2_shield.yml --limit <hostname>`

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

- **L3 (Hardening)**: Optional high-security benchmarks. See [L3 Roadmap](../ansible-dev/l3_roadmap.md) for the LVM and storage strategy.
- **L4 (System Apps)**: Core infrastructure (e.g., PMM, Splunk, NFS).
- **L5 (User Apps)**: Researcher tools (e.g., RStudio, Podman).

**Usage**:
```bash
ansible-playbook -i inventories/pstat.ini deploy_l4_system_apps.yml --limit <hostname> --tags "splunk,pmm"
```
*Note: In the future, common tag sets can be defined in `group_vars` to automate the selection of standard capabilities.*

## 🛠 Maintenance Notes
- **Agent Context**: For detailed technical history, decision logs, and AI-specific context, refer to [ansible_agent_context.txt](./ansible_agent_context.txt).
- **Adding Jump Hosts**: Add new IPs to `group_vars/pstat.yml` under `pstat_mgmt_ips`. This automatically updates both the Firewall and Fail2Ban ignore lists.
- **Customizing Roles**: All logic is atomic. To change a specific feature, edit the role in `roles/` and run the corresponding `deploy_lX.yml` playbook.

## 🛡️ Compliance (Layer 3)
Compliance is managed as an optional overlay. Use `deploy_l3_compliance.yml` with the following tags:

| Tier | Tags | Description |
| :--- | :--- | :--- |
| **Baseline** | `low_complexity,no_reboot_needed` | Basic security tools & system baseline. |
| **Standard** | `low_complexity,medium_complexity,no_reboot_needed` | Tightens filesystem mounts and SSH timeouts. |
| **Strict** | `low_complexity,medium_complexity,high_complexity` | Full audit enforcement and restrictive network policies. |

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
- Initial "Low" pass achieved ~83.7% compliance on `forger19`.
- "Medium" pass showed zero additional changes.
- **Open Items**:
    - Validate the overlap between low and medium complexity controls in the RHEL9 CUI role.
    - Isolate `/var/tmp` via LVM to prevent root partition exhaustion (CUI requirement).
    - Execute the "Home Pivot" to `/local/home` to isolate user data from OS.
    - Implement legally compliant "California-grade" MOTD (Privacy/Monitoring warnings).
    - Implement a "Dynamic Announcement" system: 
        - Use `/etc/issue` as the static legal "No Trespassing" sign.
        - Use `/etc/motd` as a dynamic bulletin board for maintenance alerts, managed via a dedicated `deploy_announcement.yml` playbook.
