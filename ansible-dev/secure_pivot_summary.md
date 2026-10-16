# Secure Pivot Summary (Seabastion)

- **Result**: A dedicated nftables table `inet pstat_forward` is active, enforcing source‑aware forwarding.
- **Implementation**: Table created via Ansible job `manage_forwarding.yml`, persisted in `/etc/nftables.d/pstat-forward.nft`.
- **Policy**: Default DROP on FORWARD; only IPs in `pstat_mgmt_fwd` (management) and `pstat_ts_fwd` (Tailscale `100.120.0.0/24`) are accepted. Established/related traffic is allowed.
- **Verification**:
  ```
  nft list table inet pstat_forward
  nft list chain inet firewalld filter_FWD_public_allow
  ```
  shows an empty `filter_FWD_public_allow` chain and the populated `pstat_forward` table.
- **Lessons Learned** (also recorded in `firewall_lessons_learned.md`):
  1. `firewall-cmd --direct` API is broken on AlmaLinux 9.
  2. Rich‑rule translation for forwarding is unreliable.
  3. Direct modification of firewalld’s owned nft table is prohibited.
  4. Creating an independent nft table at higher priority cleanly bypasses the broken layer.
  5. Persist the custom table via `/etc/nftables.d/` and load after the final firewalld reload.

The secure pivot is now live and documented.
