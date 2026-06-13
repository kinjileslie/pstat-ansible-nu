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

## 3. The Jinja2 & Firewalld XML Battle (The "Wall of Text" Saga)
**Problem**: `firewall-cmd --reload` failed with `INVALID_ZONE: not well-formed (invalid token): line X, column Y`.
**Discovery**:
1. **Whitespace Collapse**: Using `{%-` and `-%}` whitespace stripping in the loop caused the XML rules to merge into one single, massive line. The `firewalld` parser has a buffer limit (around column 100) and crashes when a line is too long.
2. **The "Null" Trap**: Using `{% if rule.port is defined %}` returns `True` even if the value is `null`. This created empty tags like `<port port="" protocol=""/>` and illegal fragments like `</>`, which the parser rejects as "invalid tokens."
**Solution**:
- **Explicit Newlines**: Removed all whitespace stripping. Every `<rule>` must start on its own newline to satisfy the parser.
- **Truthiness Checks**: Switched from `is defined` to `rule.get('port')`. This ensures that `null` values are treated as `False` and the rule is skipped entirely.
- **Defensive Dictionary Access**: Used `.get()` for all capability lookups to avoid `AnsibleUndefinedVariable` crashes when optional keys (like `service`) are missing.
**Lesson**: When templating for strict XML parsers (like `firewalld`), prioritize vertical readability and explicit truthiness over Jinja "cleverness."

## 4. Network Management Authority
**Decision**: Bypass `firewalld`'s interface binding.
**Implementation**: Use `nmcli` to bind the interface UUID to the zone.
**Reasoning**: NetworkManager overrides `firewalld` configuration; modifying the NM profile is the only way to ensure persistence.
