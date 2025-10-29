# Data Model: Permissions Format

**Feature**: 002-yaml-permissions-format
**Date**: 2025-10-29
**Status**: Complete

## Purpose

This document defines the data structures and transformations for the permissions parameter, covering both YAML hash and JSON string formats and their conversion to the GitHub API format.

---

## 1. Input Formats

### 1.1 YAML Hash Format (Recommended)

**User Input in bitrise.yml**:

```yaml
- permissions:
    contents: read
    metadata: read
    issues: write
```

**Bitrise Serialization** (automatic, happens before step.sh receives it):

```json
{"contents":"read","metadata":"read","issues":"write"}
```

**Environment Variable** (as received by step.sh):

```bash
permissions='{"contents":"read","metadata":"read","issues":"write"}'
```

**Data Structure**:
- **Type**: JSON object (after Bitrise serialization)
- **Keys**: Permission names (strings matching GitHub permission resources)
- **Values**: Access levels ("read" or "write")
- **Ordering**: Not guaranteed (JSON object, order may vary)

**Valid Examples**:

```yaml
# Single permission
- permissions:
    contents: read

# Multiple permissions
- permissions:
    contents: read
    issues: write
    pull_requests: write

# All read permissions
- permissions:
    contents: read
    metadata: read
    pull_requests: read
```

### 1.2 JSON String Format (Legacy, Supported)

**User Input in bitrise.yml**:

```yaml
- permissions: '{"contents":"read","metadata":"read","issues":"write"}'
```

**Environment Variable** (as received by step.sh):

```bash
permissions='{"contents":"read","metadata":"read","issues":"write"}'
```

**Data Structure**:
- **Type**: String containing JSON object
- **Keys**: Permission names (strings matching GitHub permission resources)
- **Values**: Access levels ("read" or "write")
- **Ordering**: As specified by user (preserved in JSON string)

**Valid Examples**:

```yaml
# Single permission
- permissions: '{"contents":"read"}'

# Multiple permissions
- permissions: '{"contents":"read","issues":"write","pull_requests":"write"}'

# All read permissions
- permissions: '{"contents":"read","metadata":"read","pull_requests":"read"}'
```

### 1.3 Format Equivalence

**Key Insight**: Both formats are **identical after Bitrise serialization**.

| Format | User Input | Environment Variable (step.sh receives) |
|--------|------------|----------------------------------------|
| YAML Hash | `contents: read`<br>`issues: write` | `'{"contents":"read","issues":"write"}'` |
| JSON String | `'{"contents":"read","issues":"write"}'` | `'{"contents":"read","issues":"write"}'` |

**Implication**: No format detection needed in step.sh - both are JSON strings.

---

## 2. GitHub API Format

### 2.1 API Request Structure

**GitHub Apps Installation Token API** expects permissions as a nested object:

```json
{
  "permissions": {
    "permission_name": "access_level",
    "permission_name": "access_level"
  }
}
```

**Example API Request Body**:

```json
{
  "permissions": {
    "contents": "read",
    "metadata": "read",
    "issues": "write"
  }
}
```

**Transformation from Environment Variable**:

```bash
# Input (environment variable)
permissions='{"contents":"read","metadata":"read","issues":"write"}'

# Transformation (jq wrapping)
permissions_json='{"permissions":{"contents":"read","metadata":"read","issues":"write"}}'

# Current implementation (step.sh)
permissions_json="{\"permissions\":${permissions}}"
```

### 2.2 API Constraints

**Permission Names** (resource types):
- Must match GitHub-defined permission resources (e.g., `contents`, `issues`, `metadata`, `pull_requests`)
- Case-sensitive (lowercase required)
- Validated by GitHub API (step.sh does not validate permission names)

**Access Levels**:
- Valid values: `"read"` or `"write"`
- Validated by GitHub API (step.sh does not validate access levels)

**Empty Permissions**:
- If `permissions` parameter is omitted or empty, GitHub API grants all permissions configured for the app
- Behavior: `POST /app/installations/{installation_id}/access_tokens` without `permissions` field

---

## 3. Transformation Flow

### 3.1 End-to-End Flow

```text
┌─────────────────────────────────────────────────────────────────────┐
│ 1. USER INPUT (bitrise.yml)                                         │
├─────────────────────────────────────────────────────────────────────┤
│ YAML Hash Format:           JSON String Format:                     │
│   - permissions:              - permissions: '{"contents":"read"}'  │
│       contents: read                                                │
└─────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 2. BITRISE SERIALIZATION (automatic)                                │
├─────────────────────────────────────────────────────────────────────┤
│ YAML hash → JSON string conversion                                  │
│ Result: Both formats become identical JSON strings                  │
└─────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 3. ENVIRONMENT VARIABLE (step.sh input)                             │
├─────────────────────────────────────────────────────────────────────┤
│ permissions='{"contents":"read"}'                                   │
└─────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 4. VALIDATION (step.sh)                                             │
├─────────────────────────────────────────────────────────────────────┤
│ echo "$permissions" | jq empty 2>/dev/null                          │
│ Validates: JSON syntax, structure                                   │
└─────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 5. GITHUB API FORMAT CONVERSION (step.sh)                           │
├─────────────────────────────────────────────────────────────────────┤
│ permissions_json="{\"permissions\":${permissions}}"                 │
│ Result: {"permissions":{"contents":"read"}}                         │
└─────────────────────────────────────────────────────────────────────┘
                                     │
                                     ▼
┌─────────────────────────────────────────────────────────────────────┐
│ 6. GITHUB API REQUEST (step.sh)                                     │
├─────────────────────────────────────────────────────────────────────┤
│ curl -d "$permissions_json" \                                       │
│   https://api.github.com/app/installations/{id}/access_tokens       │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 Code Implementation (step.sh)

**Current Implementation** (no changes needed):

```bash
# Validation
if [ -n "$permissions" ]; then
  # Validate JSON format
  if ! echo "$permissions" | jq empty 2>/dev/null; then
    echo "Error: Invalid permissions format: must be valid JSON" >&2
    exit $EXIT_VALIDATION_ERROR
  fi

  # Convert to GitHub API format
  permissions_json="{\"permissions\":${permissions}}"
fi

# API request
if [ -n "$permissions_json" ]; then
  response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $jwt_token" \
    -H "Accept: application/vnd.github+json" \
    -d "$permissions_json" \
    "$api_url")
else
  # No permissions specified - use all app permissions
  response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: Bearer $jwt_token" \
    -H "Accept: application/vnd.github+json" \
    "$api_url")
fi
```

**Enhanced Error Messages** (optional improvement):

```bash
if ! echo "$permissions" | jq empty 2>/dev/null; then
  echo "Error: Invalid permissions format" >&2
  echo "Expected: YAML hash (e.g., contents: read) or valid JSON string" >&2
  echo "Received: $permissions" >&2
  exit $EXIT_VALIDATION_ERROR
fi
```

---

## 4. Validation Rules

### 4.1 Syntactic Validation (step.sh)

**JSON Syntax Validation**:
- **Tool**: `jq empty`
- **Validates**:
  - Valid JSON structure (braces, quotes, commas)
  - Proper escaping of special characters
  - No trailing commas
  - Balanced brackets
- **Does NOT validate**:
  - Permission names (deferred to GitHub API)
  - Access levels (deferred to GitHub API)
  - Permission existence (deferred to GitHub API)

**Validation Logic**:

```bash
# Valid: {"contents":"read"}
echo '{"contents":"read"}' | jq empty  # Exit code 0

# Invalid: missing quotes
echo '{contents:read}' | jq empty  # Exit code 4

# Invalid: trailing comma
echo '{"contents":"read",}' | jq empty  # Exit code 4
```

### 4.2 Semantic Validation (GitHub API)

**GitHub API validates**:
- Permission names match defined resources
- Access levels are "read" or "write"
- App has the requested permissions configured
- Installation grants the requested permissions

**API Error Examples**:

```json
// Unknown permission name
{
  "message": "Invalid permissions: unknown_permission is not a valid permission",
  "documentation_url": "..."
}

// Invalid access level
{
  "message": "Invalid permissions: contents must be 'read' or 'write'",
  "documentation_url": "..."
}

// App doesn't have permission
{
  "message": "The installation does not have the required permissions",
  "documentation_url": "..."
}
```

### 4.3 Edge Cases

| Case | YAML Hash Input | JSON String Input | Validation Result |
|------|-----------------|-------------------|-------------------|
| Empty hash | `permissions:` (nothing) | `permissions: ''` | Passes (no validation, all app permissions granted) |
| Empty object | `permissions: {}` | `permissions: '{}'` | Passes (jq validates, GitHub API may reject) |
| Single permission | `permissions:`<br>`  contents: read` | `permissions: '{"contents":"read"}'` | Passes |
| Invalid JSON | N/A (Bitrise handles YAML) | `permissions: 'not-json'` | Fails (jq validation) |
| Missing quotes | N/A (Bitrise serializes) | `permissions: {contents:read}` | Fails (YAML parsing error before step.sh) |
| Invalid permission | `permissions:`<br>`  invalid_key: read` | `permissions: '{"invalid_key":"read"}'` | Passes (jq), fails (GitHub API) |
| Invalid access level | `permissions:`<br>`  contents: execute` | `permissions: '{"contents":"execute"}'` | Passes (jq), fails (GitHub API) |

---

## 5. Data Structure Examples

### 5.1 Minimal Valid Input

**YAML Hash**:

```yaml
- permissions:
    contents: read
```

**JSON String**:

```yaml
- permissions: '{"contents":"read"}'
```

**Environment Variable**:

```bash
permissions='{"contents":"read"}'
```

**GitHub API Format**:

```json
{"permissions":{"contents":"read"}}
```

### 5.2 Comprehensive Valid Input

**YAML Hash**:

```yaml
- permissions:
    contents: read
    metadata: read
    issues: write
    pull_requests: write
    checks: write
```

**JSON String**:

```yaml
- permissions: '{"contents":"read","metadata":"read","issues":"write","pull_requests":"write","checks":"write"}'
```

**Environment Variable**:

```bash
permissions='{"contents":"read","metadata":"read","issues":"write","pull_requests":"write","checks":"write"}'
```

**GitHub API Format**:

```json
{
  "permissions": {
    "contents": "read",
    "metadata": "read",
    "issues": "write",
    "pull_requests": "write",
    "checks": "write"
  }
}
```

### 5.3 Empty/Omitted Permissions

**YAML Hash** (omitted):

```yaml
- github-apps-installation-token:
    inputs:
    - app_id: $GITHUB_APP_ID
    - installation_id: $GITHUB_INSTALLATION_ID
    - private_pem: $GITHUB_APP_PRIVATE_PEM
    # permissions not specified
```

**Environment Variable**:

```bash
permissions=''  # Empty string
```

**GitHub API Request** (no permissions field):

```json
{}
```

**Result**: GitHub API grants all permissions configured for the app installation.

---

## 6. Permission Resources Reference

### 6.1 Common GitHub App Permissions

| Resource | Access Levels | Description |
|----------|---------------|-------------|
| `contents` | `read`, `write` | Repository contents, commits, branches |
| `issues` | `read`, `write` | Issues and related comments |
| `metadata` | `read` | Repository metadata (always read-only) |
| `pull_requests` | `read`, `write` | Pull requests and related comments |
| `checks` | `read`, `write` | Checks on code (CI/CD status) |
| `statuses` | `read`, `write` | Commit statuses |
| `deployments` | `read`, `write` | Deployments and deployment statuses |
| `actions` | `read`, `write` | GitHub Actions workflows |
| `packages` | `read`, `write` | GitHub Packages |

**Note**: This is not an exhaustive list. GitHub maintains the authoritative list of permissions in their API documentation.

### 6.2 Read-Only Permissions

Some permissions only support `read` access:
- `metadata` (always read-only)

### 6.3 Write Implies Read

When `write` access is granted, `read` access is implicitly included:
- `"contents": "write"` grants both read and write access to repository contents

---

## 7. Implementation Impact

### 7.1 No Code Changes to Parsing Logic

**Key Finding**: Existing step.sh code already handles both formats correctly.

**Why**: Bitrise serialization makes both formats identical JSON strings before step.sh execution.

**What changes**: Only step.yml configuration (documentation and `is_expand` setting).

### 7.2 Configuration Changes Only

**step.yml modifications**:

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

**Key change**: `is_expand: false` prevents Bitrise from expanding `${...}` patterns in permission names.

---

## Summary

| Aspect | Details |
|--------|---------|
| **Input Formats** | YAML hash (recommended) and JSON string (legacy) |
| **Serialization** | Bitrise converts both to identical JSON strings |
| **Validation** | `jq empty` validates JSON syntax (existing code) |
| **Transformation** | Wrap in `{"permissions": ...}` for GitHub API |
| **API Format** | Nested JSON object with permission key-value pairs |
| **Code Changes** | None (only step.yml configuration updates) |
| **Backward Compatibility** | Guaranteed (both formats identical internally) |

**Design Decision**: Leverage Bitrise's automatic YAML-to-JSON serialization to avoid complex format detection and dual code paths. This simplifies implementation and guarantees backward compatibility.
