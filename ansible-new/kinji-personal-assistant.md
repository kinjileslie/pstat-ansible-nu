# Kinji's Personal Assistant - Project Roadmap & Context
*This document serves as the high-level coordination center for the PSTAT modernization project, tracking deadlines, stakeholder communication, and strategic pivots.*

## 🗓️ Critical Deadlines
- **Mid-July**: User and Data Onboarding Deadline.
- **End of July**: **FULLY LIVE.**

## 🚩 Current Status (as of 2026-06-08)
- **L1/L2/L3**: Verified and operational.
- **L4 (Plumbing)**: `role_network_bridge` and `role_resource_guardrails` implemented.
- **Infrastructure**: `forger43` used as a "Small VM" testbed for guardrails.
- **Stability**: "Universal Sandwich" (Floor/Ceiling) memory isolation strategy finalized.

## 🎯 Immediate Next Steps (2026-06-09+)
### 1. Stakeholder Sync (Andreas)
- **Firewall Narrative**: Explain the shift from `ansible.posix.firewalld` $\rightarrow$ `nftables` due to `python-nftables` flakiness.
- **Policy-Based Access**: Detail the "VIP Lane" (Global Policies) to prevent "Campus Hijack" (overlapping CIDRs).
- **Kernel Truth**: Demonstrate that `nft list set` is the only valid verification method on AL9, rendering `ipset list` obsolete.
- **Symmetry/Compliance**: Summarize CUI hardening for SSH DoS prevention.

### 2. Technical Pivot
- **LDAP Integration**: Test SSSD/LDAP on `forger43`.
- **Home Directory Split**:
    - `/home` $\rightarrow$ LDAP users.
    - `/local/home` $\rightarrow$ Local system users.

### 3. Data Migration Strategy (~2.5 TB)
- **Source A**: `kingslanding:/home` (~1.5TB) $\rightarrow$ Requires `chown` to new LDAP UIDs.
- **Source B**: `venus:/storage2` (~1TB) $\rightarrow$ Researcher data.
- **Constraint**: Currently NFS mounts from old Ubuntu systems.

## ⚠️ Risk Management
- **Team Distractions**: The team is currently occupied with maintenance and a new AI LLM project.
- **Mitigation**: Build a "Semi-Hardened Test Image" independently. Verify the minimum viable toolset (Python, R, Containers, SSH, High RAM/Core counts) before presenting to the team to minimize their friction.
- **Investigation**: If time permits, audit `denali`, `wavelet`, and `alta` for any legacy tool requirements.
