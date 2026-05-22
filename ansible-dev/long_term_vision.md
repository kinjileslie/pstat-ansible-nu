# PSTAT Long-Term Vision & Automation Goals

## 1. GitOps Integration
- Store all Ansible roles, playbooks, and inventories in a version-controlled Git repository.
- Implement a CI/CD pipeline where commits to the repository trigger updates.

## 2. AWX Orchestration
- Use AWX (Ansible Tower) as the primary execution engine.
- Configure Webhooks in AWX to automatically trigger job templates upon Git pushes.

## 3. End-to-End Automated Provisioning
Create an "Uber-Template" in AWX that handles the full lifecycle:
1. **Provision**: Call Harvester API to create a new VM based on the hardened image.
2. **Inventory**: Dynamically add the new VM's IP and hostname to the PSTAT inventory.
3. **Deploy**: Execute the Layered Pipeline (L1 $\rightarrow$ L4) to fully configure the node.
4. **Verify**: Run the verification scripts and report success/failure back to the operator.
