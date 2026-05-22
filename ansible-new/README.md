# PSTAT Ansible Modernization
This project transforms the PSTAT node configuration from legacy monolithic roles into an atomic, layered architecture (The Layer Cake).

## 🚀 Quick Start for Operators

### 1. Baseline Deployment
To bring a new node up to the current L1/L2 baseline:
```bash
# Run the full baseline integration test
ansible-playbook -i inventories/pstat.ini test_l1_safe.yml --limit <hostname>
```
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

### 3. Architecture Overview
The system is deployed in sequential layers:
- **L1: System Base** (Updates, NTP, Repos, Tools, Users)
- **L2: The Shield** (Firewall, Fail2Ban)
- **L3: Compliance** (Optional CIS/CUI Hardening)
- **L4: Infrastructure** (Monitoring, Logging, Backups)
- **L5: Application Stack** (Researcher Tools)

## 🛠 Maintenance Notes
- **Adding Jump Hosts**: Add new IPs to `group_vars/pstat.yml` under `pstat_mgmt_ips`. This automatically updates both the Firewall and Fail2Ban ignore lists.
- **Customizing Roles**: All logic is atomic. To change a specific feature, edit the role in `roles/` and run the corresponding `deploy_lX.yml` playbook.
