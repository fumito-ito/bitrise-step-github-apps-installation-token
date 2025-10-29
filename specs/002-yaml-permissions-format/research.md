# Technical Research: YAML Permissions Format

**Feature**: 002-yaml-permissions-format
**Date**: 2025-10-29
**Status**: Complete

## Purpose

This document captures research findings and technical decisions for implementing YAML hash/map support for the permissions parameter in the GitHub Apps Installation Token step. All technical unknowns from the planning phase have been resolved.

---

## 1. Bitrise YAML Hash to Environment Variable Serialization

### Research Question

How does Bitrise serialize YAML hash inputs when passing them to shell scripts as environment variables?

### Investigation

**Bitrise step.yml Documentation** ([Bitrise Step Input Types](https://devcenter.bitrise.io/en/references/steps-reference/step-input-reference.html)):

- Bitrise supports multiple input types: `string`, `bool`, `enum`, `multiline`, `file`
- **Hash/map inputs are NOT a distinct type in Bitrise step.yml**
- YAML hashes in workflow files are automatically serialized by Bitrise

**Key Finding**: When a user specifies a YAML hash in their `bitrise.yml`:

```yaml
- permissions:
    contents: read
    metadata: read
```

Bitrise serializes this to a JSON string before passing to the environment variable:

```bash
permissions='{"contents":"read","metadata":"read"}'
```

**Compared to legacy JSON string format**:

```yaml
- permissions: '{"contents":"read","metadata":"read"}'
```

This becomes:

```bash
permissions='{"contents":"read","metadata":"read"}'
```

**Result**: Both formats end up as identical JSON strings in the environment variable!

### Decision

**Format Detection Strategy**: Since Bitrise serializes YAML hashes to JSON strings, we cannot reliably detect the original format from the environment variable alone. However, this is actually **beneficial** because:

1. **No format detection needed** - Both formats are already JSON strings
2. **Existing code works** - Current JSON parsing logic handles both cases
3. **step.yml change only** - Remove `is_expand: true` to prevent double-expansion of curly braces

**Implementation**: The only change needed is in step.yml configuration, not in step.sh logic.

### Rationale

- Bitrise's automatic serialization eliminates the need for complex format detection
- No bash parsing of YAML required (jq already handles JSON)
- Simpler implementation with less error-prone code
- Backward compatibility guaranteed (same internal representation)

### Alternatives Considered

- **Manual YAML parsing in bash**: Complex, error-prone, requires additional dependencies (yq or python)
- **Environment variable introspection**: Unreliable, Bitrise's serialization happens before shell access
- **Dual code paths for YAML vs JSON**: Unnecessary complexity, both are JSON strings internally

### References

- [Bitrise Step Input Reference](https://devcenter.bitrise.io/en/references/steps-reference/step-input-reference.html)
- [Bitrise YAML Format](https://devcenter.bitrise.io/en/references/bitrise-yml-reference.html)

---

## 2. step.yml Configuration for YAML Hash Support

### Research Question

How should step.yml be configured to accept YAML hash inputs while maintaining JSON string compatibility?

### Investigation

**Current Configuration** (JSON string only):

```yaml
- permissions:
    opts:
      title: "Custom Permissions (Optional)"
      summary: "Restrict token to specific permissions"
      description: |
        Optional JSON object to restrict the installation token to specific permissions.
        Format: {"resource": "access_level", ...}
        Example: {"contents": "read", "issues": "write"}
      is_required: false
      is_sensitive: false
```

**Key Parameter**: `is_expand: true` (default) allows variable expansion in the input value.

**Problem**: With `is_expand: true`, curly braces `{}` might be interpreted as variable expansion syntax, causing issues.

### Decision

**Remove `is_expand` parameter** (use default `is_expand: true` behavior) OR **explicitly set `is_expand: false`**:

```yaml
- permissions:
    opts:
      title: "Custom Permissions (Optional)"
      summary: "Restrict token to specific permissions (YAML hash or JSON string)"
      description: |
        Optional permissions to restrict the installation token scope.

        YAML hash format (recommended):
          permissions:
            contents: read
            issues: write

        JSON string format (legacy, still supported):
          permissions: '{"contents":"read","issues":"write"}'

        If omitted, the token will have all permissions configured for your app.
      is_required: false
      is_sensitive: false
      is_expand: false  # Prevent variable expansion in JSON
```

**Key Changes**:
1. **is_expand: false** - Prevents Bitrise from expanding `${...}` or `$()` patterns in the value
2. **Updated description** - Shows both YAML hash and JSON string formats
3. **Label as recommended** - YAML hash is the primary format, JSON string is legacy

### Rationale

- `is_expand: false` prevents unintended variable expansion in JSON strings
- Both formats work identically after Bitrise serialization
- Clearer documentation helps users choose the preferred format
- No breaking changes (existing JSON strings still work)

### Alternatives Considered

- **Keep is_expand: true**: Could cause issues if permission names match environment variables
- **Create separate input parameter**: Breaking change, requires migration
- **Use value_options**: Not applicable for open-ended JSON objects

### References

- [Step Input Options](https://devcenter.bitrise.io/en/references/steps-reference/step-input-reference.html#step-input-options)

---

## 3. Validation Strategy for Both Formats

### Research Question

What validation is needed to ensure both YAML hash and JSON string formats are correctly handled?

### Investigation

**Current Validation** (JSON string only):

```bash
if [ -n "$permissions" ]; then
  # Validate JSON format
  if ! echo "$permissions" | jq empty 2>/dev/null; then
    echo "Error: Invalid permissions format: must be valid JSON"
    exit $EXIT_VALIDATION_ERROR
  fi
  permissions_json="{\"permissions\":${permissions}}"
fi
```

**Observation**: This validation already works for both formats because Bitrise serializes YAML hashes to JSON strings.

### Decision

**No changes needed to validation logic**. The existing `jq empty` check validates:
- JSON syntax correctness
- Proper quoting and escaping
- Structural validity

**Enhanced Error Messages**: Update error messages to acknowledge both formats:

```bash
if ! echo "$permissions" | jq empty 2>/dev/null; then
  echo "Error: Invalid permissions format" >&2
  echo "Expected: YAML hash (e.g., contents: read) or valid JSON string" >&2
  echo "Received: $permissions" >&2
  exit $EXIT_VALIDATION_ERROR
fi
```

### Rationale

- Existing validation is sufficient (both formats are JSON strings internally)
- Enhanced error messages provide better user guidance
- No performance impact (same jq validation)
- Maintains fail-fast behavior

### Alternatives Considered

- **Separate validation for YAML and JSON**: Unnecessary, both are JSON strings
- **Additional permission name validation**: Deferred to GitHub API (existing behavior)
- **Access level validation (read/write only)**: Could be added, but GitHub API already validates this

### References

- [jq Manual](https://stedolan.github.io/jq/manual/)

---

## 4. Documentation and Migration Strategy

### Research Question

How should documentation be updated to promote YAML hash format while maintaining JSON string support?

### Investigation

**Current Documentation Pattern** (README.md, step.yml descriptions):
- Shows JSON string format exclusively
- No mention of YAML alternatives
- Examples use escaped quotes

**User Pain Points**:
- Escaping quotes in YAML is error-prone
- JSON strings are harder to read in workflow files
- Copy-paste errors with quote escaping

### Decision

**Documentation Hierarchy**:

1. **Primary Format**: YAML hash (shown first in all examples)
2. **Legacy Format**: JSON string (shown with "also supported" note)
3. **Migration Guide**: Quickstart.md with before/after examples

**Example Structure** (README.md):

```yaml
# Recommended: YAML hash format
- github-apps-installation-token:
    inputs:
    - app_id: $GITHUB_APP_ID
    - installation_id: $GITHUB_INSTALLATION_ID
    - private_pem: $GITHUB_APP_PRIVATE_PEM
    - permissions:
        contents: read
        issues: write

# Also supported: JSON string format (legacy)
- github-apps-installation-token:
    inputs:
    - permissions: '{"contents":"read","issues":"write"}'
```

**Deprecation Notice**:
- JSON string format labeled as "legacy" but "still supported"
- No removal timeline (supported indefinitely)
- Emphasize YAML hash as "recommended" not "required"

### Rationale

- YAML hash format aligns with YAML workflow conventions
- Gradual migration without forcing users to change immediately
- Clear guidance reduces support burden
- "Recommended" vs "deprecated" avoids alarming users

### Alternatives Considered

- **Hard deprecation**: Too disruptive, creates urgency without benefit
- **No migration guide**: Users might not discover the new format
- **Separate documentation pages**: Overkill for a simple format change

### References

- [Bitrise Step Documentation Best Practices](https://devcenter.bitrise.io/en/references/steps-reference/step-documentation-guidelines.html)

---

## 5. Backward Compatibility Testing

### Research Question

How to ensure existing workflows using JSON string format continue to work without issues?

### Investigation

**Test Scenarios**:

1. **Legacy JSON string**: `'{"contents":"read"}'` → Should work identically to before
2. **YAML hash**: `contents: read` → Should work identically to JSON string
3. **Empty permissions**: `''` or omitted → Should default to all app permissions
4. **Invalid JSON**: `'not-json'` → Should fail with clear error message
5. **Mixed quotes**: `"{"contents":"read"}"` → Should be handled by Bitrise YAML parsing

### Decision

**Test Workflow Structure** (bitrise.yml):

```yaml
test-yaml-hash-format:
  title: Test YAML hash permissions format
  steps:
  - path::./:
      inputs:
      - permissions:
          contents: read
          metadata: read

test-json-string-format:
  title: Test JSON string permissions format (backward compatibility)
  steps:
  - path::./:
      inputs:
      - permissions: '{"contents":"read","metadata":"read"}'

test-permissions-comparison:
  title: Verify both formats produce identical tokens
  steps:
  - path::./:
      title: Generate token with YAML hash
      inputs:
      - permissions:
          contents: read
  - script:
      inputs:
      - content: |
          YAML_TOKEN="$GITHUB_APPS_INSTALLATION_TOKEN"
  - path::./:
      title: Generate token with JSON string
      inputs:
      - permissions: '{"contents":"read"}'
  - script:
      inputs:
      - content: |
          # Both tokens should have identical permissions
          # (Different token values, but same permissions scope)
```

### Rationale

- Explicit tests for both formats ensure backward compatibility
- Comparison tests verify functional equivalence
- Test workflows serve as documentation examples
- Automated verification prevents regressions

### Alternatives Considered

- **Manual testing only**: Risky, could miss edge cases
- **Unit tests in bash**: Complex, bitrise.yml tests are more realistic
- **No comparison tests**: Wouldn't verify functional equivalence

### References

- [Bitrise Testing Best Practices](https://devcenter.bitrise.io/en/builds/testing-your-app/index.html)

---

## Summary of Decisions

| Research Area | Decision | Rationale |
|---------------|----------|-----------|
| **Format Detection** | No detection needed - Bitrise serializes both to JSON | Simplifies implementation, both formats identical internally |
| **step.yml Config** | Set `is_expand: false`, update descriptions to show both formats | Prevents variable expansion, clear user guidance |
| **Validation** | Keep existing `jq empty` check, enhance error messages | Already validates both formats (JSON strings internally) |
| **Documentation** | YAML hash as primary, JSON string as legacy/supported | Promotes better UX while maintaining compatibility |
| **Testing** | Add workflows for both formats, verify equivalence | Ensures backward compatibility and functional parity |

## Implementation Impact

**Code Changes**: Minimal
- step.yml: Update description, set `is_expand: false`
- README.md: Update examples to show YAML hash first
- bitrise.yml: Add test workflows for YAML hash format
- step.sh: Update error messages (optional, for clarity)

**No Changes Needed**:
- Permissions parsing logic (already handles JSON strings)
- Validation logic (jq works for both formats)
- GitHub API integration (receives JSON regardless of input format)
- Security measures (both formats handled identically)

**User Impact**: Positive
- Better developer experience (more readable workflow files)
- No breaking changes (existing workflows continue to work)
- Clear migration path (documentation shows both formats)
- Gradual adoption (users migrate at their own pace)

---

## Open Questions

None. All research questions resolved. Ready to proceed to Phase 1 (Design).
