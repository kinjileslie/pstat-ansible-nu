# PSTAT Infrastructure Decision Log

## 🛡️ Firewall & Security
- **Decision**: Adopt "Symmetry V3" (Ceiling Model).
  - **Reasoning**: Prevents "accidental" public exposure. A host's `pstat_firewall_profile` acts as a hard limit. Even if a role requests a 'Public' port, the host's 'Internal' profile will clamp it to the Campus IPSet.
- **Decision**: Use a Global Policy (`mgmt-ssh`) for admin access.
  - **Reasoning**: Ensures a permanent "Break-Glass" path for administrators that bypasses zone-based DROP targets.
- **Decision**: Implement "Symmetry" via direct XML templates rather than the `ansible.posix.firewalld` module.
  - **Reasoning**: The module was overwriting custom XMLs with default templates, wiping rich rules and changing the target from DROP to DEFAULT.
- **Decision**: Use a "Nuclear Wipe" (`rm -f`) before templating zone files.
  - **Reasoning**: AlmaLinux 9's atomic-move fails silently if a file exists, leading to "Ghost XMLs" where Ansible reports 'changed' but the disk remains old.

## 💾 Storage & Compliance
- **Decision**: Symmetric LVM Home Migration.
  - **Reasoning**: Prevents SSH lockout by using a `/mnt/home_migration` bridge during LVM deployment.
- **Decision**: Dual-stream Audit Logging.
  - **Reasoning**: Local logs for fast debugging, Syslog/Splunk for immutable compliance records.
- **Decision**: la-valuation of IPSet XMLs.
  - **Reasoning**: Confirmed that `firewall-cmd --reload` correctly instantiates XML into the kernel's `nftables` sets, rendering the manual `ipset` binary unnecessary.

## 🌐 Identity & Access
- **Decision**: Polyglot Identity Model (`nu_pink` vs `nu_gold`).
  - **Reasoning**: Supports both standard Ed25519 keys and FIPS-compliant ECDSA keys based on the `is_fips_enabled` toggle.
- **Decision**: Provisioning Key model via Cloud-Init.
  - **Reasoning**: Simplest way to establish trust between the VM and the management host (seabastion) without pre-sharing keys.

## 🖥️ Application Layer (L4)
- **Decision**: Capability-Based Role Application.
  - **Reasoning**: Decouples "what the server is" (Host Vars) from "how the service is configured" (Roles).
- **Decision**: PHP-FPM for Legacy Web Sites.
  - **Reasoning**: Using `php-fpm` with a proxy bridge to Apache allows for high performance and security, while manually extending `security.limit_extensions` allows legacy `.html` files to execute PHP.
