# Firewall Pivot Egress Zone Option

## Overview
A new, **host‑scoped** configuration variable has been introduced to control the egress zone used by the `ts-to-build` firewalld forwarding policy:

```yaml
pstat_ts_to_build_egress: "public"   # default
```

- **`public`** – The policy will masquerade traffic to the public interface (`eth0`). This is the safe default and matches the setup that was verified to work (`ping` and `ssh` to the internal build network).
- **`internal`** – If you prefer the source address to be the internal NIC (`eth1`) you can set the variable to `"internal"`.  The NAT rule will then use `eth1` as the egress interface.

The variable is defined in **`ansible-new/roles/role_firewall/defaults/main.yml`** with a default value of `"public"`.  It can be overridden **per‑host** in a host‑vars file.  The seabastion host now contains the override:

```yaml
# ansible-new/host_vars/seabastion.yml
pstat_ts_to_build_egress: "public"
```

## How it works
1. `pstat_forwarding_policies` in `defaults/main.yml` references the variable:
   ```yaml
   egress: "{{ pstat_ts_to_build_egress | default('public') }}"
   ```
2. When the `network_bridge_transit` capability is present (only on hosts that need the pivot), the `manage_forward_policy.yml` role creates the forward policy using the egress zone defined by the variable.
3. A task has been added to **explicitly enable masquerade** for each forward policy, guaranteeing the NAT rule is created regardless of firewalld quirks.

## When to use it
- **Default (`public`)** – Recommended for most deployments. The packet is NAT‑ed to the public IP (`10.x.x.x`) which is already routable from the internal subnet.
- **Internal (`internal`)** – Useful if the internal network already knows how to reach the bastion’s internal IP (`169.231.x.x`) and you wish to keep the source address within the protected subnet.

## Adding the option to other hosts
If a different host should also use this pivot, simply:
1. Add `network_bridge_transit` to its `pstat_capabilities` list.
2. (Optional) Override the egress zone in that host’s `host_vars`:
   ```yaml
   pstat_ts_to_build_egress: "internal"
   ```
3. Re‑run the L2 shield playbook.

The configuration is fully idempotent and managed by Ansible, ensuring that future deployments retain the correct egress zone without manual `firewall‑cmd` steps.
