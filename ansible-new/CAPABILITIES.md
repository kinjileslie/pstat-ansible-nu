# PSTAT Capability Registry

This document tracks the "Capability Toggles" used in Layer 4 (Plumbing) and Layer 5 (Apps). 
Instead of server-specific roles, we assign capabilities via `host_vars`.

## 🌐 Network Capabilities

### `is_network_bridge`
- **Description**: Configures the node as a "Core-and-Spoke" bridge between isolated VLANs (e.g., 1173 and 2176).
- **Implementation**: `role_network_bridge`
- **Behavior**: 
    - Sets the external interface as the primary default gateway.
    - Configures the internal interface to ignore DHCP-provided gateways.
    - Implements static routes for the internal target fleet.
- **Required Host Vars**:
    - `bridge_internal_iface`: Device name (e.g., "eth0")
    - `bridge_internal_gw`: Gateway for internal traffic.
    - `bridge_internal_routes`: List of `{network, via}` mappings.

---

## 🛡️ Security Capabilities
*(To be defined as L3/L4 evolves)*

## 📦 Application Capabilities
*(To be defined in L5)*
