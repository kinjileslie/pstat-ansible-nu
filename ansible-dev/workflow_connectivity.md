# PSTAT Deployment & Connectivity Workflow

## Hardware Chain
Fulcrum (M3 MBA) $\rightarrow$ Flanker $\rightarrow$ Bobby $\rightarrow$ Ctrl1 $\rightarrow$ Target VM

## The "Publishing" Workflow
To sync code from the local development environment to the execution point (Bobby):

1. **Local Dev**: Code is edited on **Fulcrum**.
2. **Sync to Flanker**: Code is pushed to the mount point on Flanker:
   `rsync -avz ansible-new/ flanker:~/bobby_ansible/`
3. **The Mount**: Flanker mounts Bobby's directory via SSHFS:
   `sshfs bobby:/root/kinji/ansible/ /home/kinji/bobby_ansible/`
4. **Execution**: Log into **Bobby** and run playbooks from `/root/kinji/ansible/`.

## Key Path Mapping
- **Remote (Bobby)**: `/root/kinji/ansible/`
- **Local (Flanker)**: `/home/kinji/bobby_ansible/`
