# PSTAT Ansible Decision Log
# This file records key technical decisions to prevent decision drift.

| Date | Decision | Rationale | Impact |
| :--- | :--- | :--- | :--- |
| 2026-05-20 | Atomic Role Architecture | Shift from monolithic "Mega-Roles" to single-purpose atomic roles to increase maintainability and reduce implicit logic. | All future roles must be single-purpose; `site.yml` becomes the explicit "Order Form". |
| 2026-05-20 | Execution Point: Bobby | Run Ansible from 'Bobby' to leverage its internal SSH config and avoid DNS/Tunneling failures from the client. | All playbooks and inventories will be managed/executed on Bobby. |
| 2026-05-20 | Atomic Role Architecture | Shift from monolithic "Mega-Roles" to single-purpose atomic roles to increase maintainability and reduce implicit logic. | All future roles must be single-purpose; `site.yml` becomes the explicit "Order Form". |
| 2026-05-20 | Execution Point: Bobby | Run Ansible from 'Bobby' to leverage its internal SSH config and avoid DNS/Tunneling failures from the client. | All playbooks and inventories will be managed/executed on Bobby. |
| 2026-05-20 | AlmaLinux 9 Baseline | Use `kinji_pstat.yml` as the cloud-init source of truth for the baseline system state. | Defines the starting point for L1 and L2 roles. |
| 2026-05-20 | Investigation: @lsit-common lockout | Observed immediate SSH connection drops (KEX reset) after installing @lsit-common group on forger2, 3, and 4. | Root cause identified as an OpenSSL version mismatch (Built against 30000070, found 30500010) causing sshd to crash. |
| 2026-05-21 | Firewall Zone Strategy | Implement a zone-based architecture (internal, monitoring, backup-network, campus) using Firewalld IP sets rather than a flat public zone. | Allows source-based access control; rules are tied to identities (e.g., "Backup Servers") rather than individual IPs. |
| 2026-05-21 | Removal of PXC Zone | Decided to drop the PXC (Percona) zone and associated IP set (169.231.230.59, .79, etc.). | PXC specific rules are not required for the current baseline. |
| 2026-05-21 | Tagged Roles Implementation | Implemented Ansible tags for all L1 and L2 roles (updates, repos, tools, users, firewall). | Enables selective execution of specific roles via --tags, reducing deployment time and allowing for targeted testing of specific layers. |
| 2026-05-21 | User Identity Strategy | Pivot from local user management to a future LDAP/SSSD model. Current iteration focus is reduced to a single local 'support' break-glass account with passwordless sudo. | Simplifies L1 implementation; defers complex identity integration to a later phase. |

| 2026-05-21 | Firewall Convergence Model | Decided to use an additive/idempotent approach for firewall rules rather than a full state-purge. Manual reset of /etc/firewalld/ is used for total convergence if needed. | Keeps the role simple and avoids risky "wipe-and-replace" cycles on production nodes. |

| 2026-05-21 | Firewall Management Model | Confirmed "Gatekeeper" model: central service list in role_firewall. Services are opened even if the app is not yet installed. | Maintains a single audit point for security posture; matches existing status quo. |
| 2026-05-21 | Agentless Architecture | Electing NOT to install Ansible on target nodes. | Reduces attack surface and removes unnecessary software from production VMs. |
| 2026-05-21 | Splunk Installation Path | Identified that Splunk Forwarder requires specific RPM versioning and checksums. | Will be implemented as a custom deployment in L3 rather than a simple DNF install. |
| 2026-05-21 | NTP/Time Strategy | Mirror 'alta' configuration: use internal time servers (128.111.1.5/6) instead of public pools. | Ensures cluster-wide time consistency and avoids public network jitter/jumps seen on 'roble'. |
| 2026-05-21 | Firewall Policy Versioning | Implement a metadata "breadcrumb" file at /etc/ansible/firewall_version.txt. | Allows quick verification of which policy version/date is applied to a live node. |

| 2026-05-21 | CIS/CUI Hardening Strategy | Decided against using booleans in host_vars to trigger hardening. Instead, CIS/CUI hardening will be implemented as a separate, standalone policy playbook. | Prevents "shadow configuration" and ensures that applying high-impact hardening is an explicit, conscious administrative action rather than a hidden variable. |

| 2026-05-21 | Playbook Delivery Model | Decided on Layer-Specific Playbooks (one per layer) rather than a single master or persona-based model. | Provides an explicit, linear deployment path and high auditability while maintaining modularity. Allows for targeted updates of specific layers without executing the entire stack. |

| 2026-05-21 | Dual-Track Playbook Strategy | Implementation of both "Deliverable Playbooks" (layer-specific) and a "Testing Harness" (integration playbook). | Ensures that the lapped deployment process is formal and auditable, while maintaining a single, tagged file for rapid iteration and integration testing. |
