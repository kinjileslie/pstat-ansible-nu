# PSTAT Ansible Modernization
This project transforms the PSTAT node configuration from legacy monolithic roles into an atomic, layered architecture (The Layer Cake).

## 🚀 Quick Start for Operators

### 1. Baseline Deployment
To bring a new node up to the current L1/L2 baseline:
```bash
# Run the full baseline integration test
ansible-playbook -i inventories/pstat.ini test_l1_safe.yml --limit <hostname>
```

**Note on Provisioning**: New VMs are instantiated via Cloud-Init with the **Provisioning Key (Bobby)**. The subsequent L1 deployment automatically populates the administrative SSH keys managed in `group_vars/pstat.yml`.
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

- **L3 (Hardening)**: Optional high-security benchmarks.
- **L4 (System Apps)**: Core infrastructure (e.g., PMM, Splunk, NFS).
- **L5 (User Apps)**: Researcher tools (e.g., RStudio, Podman).

**Usage**:
```bash
ansible-playbook -i inventories/pstat.ini deploy_l4_system_apps.yml --limit <hostname> --tags "splunk,pmm"
```
*Note: In the future, common tag sets can be defined in `group_vars` to automate the selection of standard capabilities.*

## 🛠 Maintenance Notes
- **Adding Jump Hosts**: Add new IPs to `group_vars/pstat.yml` under `pstat_mgmt_ips`. This automatically updates both the Firewall and Fail2Ban ignore lists.
- **Customizing Roles**: All logic is atomic. To change a specific feature, edit the role in `roles/` and run the corresponding `deploy_lX.yml` playbook.
