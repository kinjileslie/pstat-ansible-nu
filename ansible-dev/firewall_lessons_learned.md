# L2 Shield V2: Lessons Learned & Decision Log

## 1. The Transport Mystery (The "Lying" Template)
**Problem**: `ansible.builtin.template` reported success, but files on Tom, Dick, and Harry were not updating.
**Discovery**: Verified via 'Control Node' (Lloyd) that the module worked on fresh images.
**Root Cause**: Atomic rename failure on configured nodes.
**Decision**: Precede all zone templating with a direct `sudo rm -f` to clear the path and force a fresh write.

## 2. The XML Schema War
**Problem**: `firewall-cmd --reload` failed with `PARSE_ERROR: Unexpected element target` and `Unexpected element rich-rule`.
**Discovery**: The AlmaLinux 9 parser is strictly sequential and rejects non-standard tags.
**Implementation Choices**:
- **Target**: Moved `target="DROP"` from a child element to an attribute of the `<zone>` tag.
- **Rich Rules**: Changed `<rich-rule>` to `<rule>`.
- **Sequence**: Standardized on `<zone target="...">` $\rightarrow$ `<short>` $\rightarrow$ `<rule>`.
- **Syntax**: Ensured the XML declaration is at absolute character 0.

## 3. The "Symmetry" Verification Model
**Decision**: Implement a "Canary" system.
**Implementation**: Insert a comment `<!-- Build ID: {{ ansible_date_time.iso8601 }} -->` inside the XML.
**Value**: Allows instant verification of whether a deployment actually changed the disk, bypassing Ansible's potentially misleading return codes.

## 4. Network Management Authority
**Decision**: Bypass `firewalld`'s interface binding.
**Implementation**: Use `nmcli` to bind the interface UUID to the zone.
**Reasoning**: NetworkManager overrides `firewalld` configuration; modifying the NM profile is the only way to ensure persistence.
