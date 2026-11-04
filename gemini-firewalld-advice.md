# Technical Refactoring Spec: Native Firewalld Policies for `seabastion` (AlmaLinux 9)

## Executive Summary

We are completely decommissioning the custom `pstat_forward` `nftables` shim (priority `-10`) and avoiding deprecated `firewall-cmd --direct` commands. On AlmaLinux 9 (Firewalld 1.3+), inter-interface forwarding and subnet routing are handled natively using **Firewalld Policy Objects**.

This specification provides the exact configuration and Ansible tasks required to implement a single-engine, 100% native Firewalld architecture.

---

## Why Previous Firewalld Policy Attempts Failed

When configuring Firewalld policies for forwarding, failures usually stem from one of three issues:

1. **Unassigned Interfaces or Zones:** A policy only triggers if the packet's entry interface belongs to the `ingress-zone` AND its exit interface belongs to the `egress-zone`. If `eth1` or `tailscale0` default to `public`, the policy match fails silently.
2. **Missing Kernel IP Forwarding:** Firewalld controls packet filtering, but the Linux kernel must be explicitly told to route packets between interfaces (`net.ipv4.ip_forward = 1`).
3. **D-Bus vs. Manual XML Edits:** Direct XML template editing often creates syntax or ordering mismatches that break `firewall-cmd --reload`. Using `ansible.posix.firewalld` (which communicates via D-Bus) avoids XML parser errors.

---

## Targeted Architecture

* **`eth0` (Public):** Assigned to `public` zone.
* **`eth1` (Build Subnet):** Assigned to `internal` zone.
* **`tailscale0` (Tailnet):** Assigned to `trusted` zone (or custom `tailscale` zone).
* **Policy `ts-to-build`:** Routes traffic from `trusted` (ingress) $\rightarrow$ `internal` (egress) with `target: ACCEPT`.

---

## CLI Proof-of-Concept Commands

To test manually before running Ansible:

```bash
# 1. Clean up custom nftables shims
nft delete table inet pstat_forward 2>/dev/null || true

# 2. Assign interfaces to respective zones
firewall-cmd --permanent --zone=public --change-interface=eth0
firewall-cmd --permanent --zone=internal --change-interface=eth1
firewall-cmd --permanent --zone=trusted --change-interface=tailscale0

# 3. Create the forwarding policy object
firewall-cmd --permanent --new-policy ts-to-build
firewall-cmd --permanent --policy ts-to-build --add-ingress-zone trusted
firewall-cmd --permanent --policy ts-to-build --add-egress-zone internal
firewall-cmd --permanent --policy ts-to-build --set-target ACCEPT

# 4. Enable SSH access from management & tailscale IPs into the host
firewall-cmd --permanent --zone=internal --add-service=ssh
firewall-cmd --permanent --zone=trusted --add-service=ssh

# 5. Apply changes
firewall-cmd --reload

```

---

## Production Ansible Implementation (`tasks/main.yml`)

Use `ansible.posix.firewalld` (v2.3+) to manage state natively over D-Bus:

```yaml
---
- name: Ensure Kernel Forwarding and Reverse-Path Filtering are enabled
  ansible.posix.sysctl:
    name: "{{ item.key }}"
    value: "{{ item.value }}"
    state: present
    sysctl_file: /etc/sysctl.d/99-pstat-routing.conf
    reload: true
  loop:
    - { key: 'net.ipv4.ip_forward', value: '1' }
    - { key: 'net.ipv4.conf.all.rp_filter', value: '1' }
    - { key: 'net.ipv4.conf.default.rp_filter', value: '1' }

- name: Bind interfaces to designated Firewalld zones
  ansible.posix.firewalld:
    zone: "{{ item.zone }}"
    interface: "{{ item.interface }}"
    permanent: true
    state: enabled
  loop:
    - { zone: 'public', interface: 'eth0' }
    - { zone: 'internal', interface: 'eth1' }
    - { zone: 'trusted', interface: 'tailscale0' }
  notify: Reload firewalld

- name: Allow SSH access in trusted and internal zones
  ansible.posix.firewalld:
    zone: "{{ item }}"
    service: ssh
    permanent: true
    state: enabled
  loop:
    - internal
    - trusted
  notify: Reload firewalld

- name: Configure native Firewalld Policy for Tailscale-to-Build forwarding
  ansible.posix.firewalld:
    policy: ts-to-build
    ingress_zone: trusted
    egress_zone: internal
    target: ACCEPT
    permanent: true
    state: enabled
  notify: Reload firewalld

- name: Remove legacy custom nftables configuration files
  ansible.builtin.file:
    path: "{{ item }}"
    state: absent
  loop:
    - /etc/nftables/pstat_forward.nft
    - /etc/firewalld/direct/99-pstat-forward.nft

```

---

## Verification Commands

After applying the configuration, verify that Firewalld has compiled the policy into its internal `nftables` ruleset:

```bash
# Verify active zones and interface bindings
firewall-cmd --get-active-zones

# Verify the policy status
firewall-cmd --info-policy=ts-to-build

# Confirm inter-zone forwarding works from a Tailscale node
ping -c 3 <internal-build-net-ip>
ssh user@<internal-build-net-ip>

```
