# Input/Output Contract: YAML Permissions Format

**Feature**: 002-yaml-permissions-format
**Date**: 2025-10-29
**Status**: Complete

## Purpose

This document defines the input/output contract for the GitHub Apps Installation Token step with YAML hash format support. It specifies how inputs are accepted, validated, and how outputs are produced.

---

## 1. Input Contract

### 1.1 Input Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `app_id` | String (numeric) | Yes | - | GitHub App ID |
| `installation_id` | String (numeric) | Yes | - | GitHub App Installation ID |
| `private_pem` | String (multiline) | Yes | - | RSA private key in PEM format |
| **`permissions`** | **String/Hash** | **No** | **Empty (all app permissions)** | **Permissions restriction (YAML hash or JSON string)** |

**Updated Parameter**: `permissions`

**Previous Behavior**:
- Type: String (JSON format only)
- Example: `'{"contents":"read","issues":"write"}'`

**New Behavior**:
- Type: String (after Bitrise serialization) - accepts both YAML hash and JSON string in bitrise.yml
- Example (YAML hash):
  ```yaml
  permissions:
    contents: read
    issues: write
  ```
- Example (JSON string): `'{"contents":"read","issues":"write"}'`

**Backward Compatibility**: JSON string format continues to work identically.

### 1.2 Input Format Detection

**User Perspective** (in bitrise.yml):

```yaml
# Format 1: YAML Hash (Recommended)
- github-apps-installation-token:
    inputs:
    - app_id: $GITHUB_APP_ID
    - installation_id: $GITHUB_INSTALLATION_ID
    - private_pem: $GITHUB_APP_PRIVATE_PEM
    - permissions:
        contents: read
        issues: write

# Format 2: JSON String (Legacy, Supported)
- github-apps-installation-token:
    inputs:
    - app_id: $GITHUB_APP_ID
    - installation_id: $GITHUB_INSTALLATION_ID
    - private_pem: $GITHUB_APP_PRIVATE_PEM
    - permissions: '{"contents":"read","issues":"write"}'
```

**Step Perspective** (environment variable in step.sh):

Both formats arrive as identical JSON strings:

```bash
permissions='{"contents":"read","issues":"write"}'
```

**Contract Guarantee**: Format detection is NOT required in step.sh because Bitrise serialization normalizes both formats to JSON strings.

### 1.3 Input Validation

#### 1.3.1 Existing Validation (Unchanged)

**app_id**:
- Must be non-empty
- Must be numeric
- Error message: "App ID must be numeric: received '{value}'"

**installation_id**:
- Must be non-empty
- Must be numeric
- Error message: "Installation ID must be numeric: received '{value}'"

**private_pem**:
- Must contain "BEGIN RSA PRIVATE KEY" and "END RSA PRIVATE KEY" markers
- Error message: "Invalid PEM format: ensure the key includes BEGIN/END RSA PRIVATE KEY markers"

#### 1.3.2 Updated Validation (permissions)

**Validation Logic**:

```bash
if [ -n "$permissions" ]; then
  # Validate JSON syntax
  if ! echo "$permissions" | jq empty 2>/dev/null; then
    echo "Error: Invalid permissions format" >&2
    echo "Expected: YAML hash (e.g., contents: read) or valid JSON string" >&2
    echo "Received: $permissions" >&2
    exit $EXIT_VALIDATION_ERROR
  fi
fi
```

**Valid Inputs**:
- Empty string `''` - passes validation (no permissions restriction)
- Valid JSON object `'{"contents":"read"}'` - passes validation
- YAML hash (serialized by Bitrise) `{"contents":"read"}` - passes validation

**Invalid Inputs**:
- Malformed JSON `'not-json'` - fails with error message
- Invalid JSON syntax `'{contents:read}'` - fails with error message
- Unclosed braces `'{"contents":"read"'` - fails with error message

**Error Messages**:

| Input Format | User Input | Error Message |
|--------------|------------|---------------|
| YAML Hash | `permissions:`<br>`  invalid syntax` | Bitrise YAML parsing error (before step.sh) |
| JSON String | `permissions: 'not-json'` | "Error: Invalid permissions format<br>Expected: YAML hash (e.g., contents: read) or valid JSON string<br>Received: not-json" |
| JSON String | `permissions: '{contents:read}'` | "Error: Invalid permissions format<br>Expected: YAML hash (e.g., contents: read) or valid JSON string<br>Received: {contents:read}" |

**Exit Code**: `1` (EXIT_VALIDATION_ERROR)

---

## 2. Output Contract

### 2.1 Output Variables

| Variable | Type | Description | Lifetime |
|----------|------|-------------|----------|
| `GITHUB_APPS_INSTALLATION_TOKEN` | String | Installation access token | 1 hour (GitHub default) |

**No changes to output contract** - token generation and export remain identical.

### 2.2 Output Format

**Success Output**:

```
Successfully generated GitHub Apps installation token (expires in 1 hour)
Token exported to GITHUB_APPS_INSTALLATION_TOKEN
```

**Environment Variable**:

```bash
GITHUB_APPS_INSTALLATION_TOKEN="ghs_abcdef1234567890..."
```

**Usage in subsequent steps**:

```bash
curl -H "Authorization: Bearer $GITHUB_APPS_INSTALLATION_TOKEN" \
  https://api.github.com/repos/owner/repo/issues
```

---

## 3. Error Contract

### 3.1 Exit Codes

| Code | Name | Trigger | User Action |
|------|------|---------|-------------|
| `0` | Success | Token generated and exported | None |
| `1` | Validation Error | Invalid input parameters | Fix input values in bitrise.yml |
| `2` | API Error | GitHub API failure | Check credentials, network, GitHub status |
| `3` | Envman Error | Token export failed | Check Bitrise environment, report issue |

**No changes to exit codes** - all existing error handling preserved.

### 3.2 Validation Error Messages

**New Error Message** (permissions validation):

```
Error: Invalid permissions format
Expected: YAML hash (e.g., contents: read) or valid JSON string
Received: <actual_value>
```

**Enhanced Error Guidance**:
- Acknowledges both YAML hash and JSON string formats
- Shows example of valid YAML hash format
- Displays the actual received value for debugging

**Existing Error Messages** (unchanged):
- "App ID is required: set the app_id input parameter"
- "App ID must be numeric: received '{value}'"
- "Installation ID is required: set the installation_id input parameter"
- "Installation ID must be numeric: received '{value}'"
- "Private PEM key is required: set the private_pem input parameter"
- "Invalid PEM format: ensure the key includes BEGIN/END RSA PRIVATE KEY markers"

### 3.3 API Error Messages (Unchanged)

| HTTP Code | Error Message | User Action |
|-----------|---------------|-------------|
| 401 | "Authentication failed (HTTP 401): Invalid JWT or App ID" | Verify App ID and private key match |
| 403 | "Permission denied (HTTP 403): App may not have access" | Check app installation status |
| 404 | "Installation not found (HTTP 404): Check installation_id" | Verify installation ID is correct |
| 422 | "Invalid request (HTTP 422): {github_message}" | Check GitHub API response details |
| 503 | "GitHub API unavailable after retry (HTTP 503)" | Wait and retry, check GitHub status |

---

## 4. Behavior Contract

### 4.1 Permissions Behavior

**When permissions is empty or omitted**:
- Token receives ALL permissions configured for the GitHub App installation
- No `permissions` field sent to GitHub API
- Behavior identical to previous version

**When permissions is specified (YAML hash)**:
- Bitrise serializes YAML hash to JSON string
- step.sh validates JSON syntax with `jq empty`
- step.sh wraps in `{"permissions": ...}` for GitHub API
- Token receives ONLY the specified permissions

**When permissions is specified (JSON string)**:
- step.sh validates JSON syntax with `jq empty`
- step.sh wraps in `{"permissions": ...}` for GitHub API
- Token receives ONLY the specified permissions

**Behavioral Equivalence**:

```yaml
# These three configurations produce IDENTICAL tokens:

# YAML hash
- permissions:
    contents: read
    issues: write

# JSON string
- permissions: '{"contents":"read","issues":"write"}'

# JSON string (different spacing, same result)
- permissions: '{"issues":"write","contents":"read"}'
```

### 4.2 Validation Sequence

**Execution Order** (unchanged):

1. Validate `app_id` (non-empty, numeric)
2. Validate `installation_id` (non-empty, numeric)
3. Validate `private_pem` (PEM format markers)
4. Validate `permissions` (if provided, JSON syntax)
5. Generate JWT token
6. Call GitHub API
7. Export token to environment

**Fail-Fast Behavior**: First validation failure exits immediately with exit code 1.

### 4.3 Backward Compatibility Guarantees

**Contract Promises**:

1. **Existing workflows unchanged**: JSON string format continues to work identically
2. **Same validation**: JSON syntax validation applies to both formats equally
3. **Same API calls**: GitHub API receives identical request bodies
4. **Same token output**: Tokens have identical permissions regardless of input format
5. **Same error handling**: Exit codes and error messages preserved (with enhanced guidance)

**Breaking Change Policy**: None - this is a backward-compatible enhancement.

---

## 5. Configuration Contract (step.yml)

### 5.1 Updated permissions Input Definition

**New Configuration**:

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

        Common permissions:
        - contents: Repository contents (read/write)
        - issues: Issues and comments (read/write)
        - pull_requests: Pull requests (read/write)
        - metadata: Repository metadata (read only)
        - checks: Checks on code (read/write)

        See GitHub documentation for full permission list:
        https://docs.github.com/en/rest/apps/apps#create-an-installation-access-token-for-an-app
      is_required: false
      is_sensitive: false
      is_expand: false
```

**Key Changes from Original**:

| Aspect | Original | Updated |
|--------|----------|---------|
| Title | "Custom Permissions (Optional)" | "Custom Permissions (Optional)" (unchanged) |
| Summary | "Restrict token to specific permissions" | "Restrict token to specific permissions (YAML hash or JSON string)" |
| Description | Shows JSON string format only | Shows both YAML hash (primary) and JSON string (legacy) |
| is_expand | Not set (default true) | **false** (prevents variable expansion) |

**Rationale for is_expand: false**:
- Prevents Bitrise from expanding `${...}` or `$()` patterns in permission names
- Avoids issues if permission names coincidentally match environment variable names
- Ensures JSON strings are passed literally to step.sh

### 5.2 Unchanged Input Definitions

**app_id**, **installation_id**, **private_pem** remain identical to original step.yml.

---

## 6. Example Workflows

### 6.1 YAML Hash Format (Recommended)

**Minimal Example**:

```yaml
workflows:
  build:
    steps:
    - github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
        - permissions:
            contents: read
```

**Comprehensive Example**:

```yaml
workflows:
  deploy:
    steps:
    - github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
        - permissions:
            contents: read
            metadata: read
            issues: write
            pull_requests: write
            checks: write
    - script:
        title: "Create deployment status"
        inputs:
        - content: |
            #!/bin/bash
            curl -X POST \
              -H "Authorization: Bearer $GITHUB_APPS_INSTALLATION_TOKEN" \
              -H "Accept: application/vnd.github+json" \
              -d '{"state":"success"}' \
              "https://api.github.com/repos/owner/repo/deployments/123/statuses"
```

### 6.2 JSON String Format (Legacy)

**Minimal Example**:

```yaml
workflows:
  build:
    steps:
    - github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
        - permissions: '{"contents":"read"}'
```

**Comprehensive Example**:

```yaml
workflows:
  deploy:
    steps:
    - github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
        - permissions: '{"contents":"read","metadata":"read","issues":"write","pull_requests":"write","checks":"write"}'
```

### 6.3 No Permissions (All App Permissions)

**Example**:

```yaml
workflows:
  build:
    steps:
    - github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
        # No permissions specified - token has all app permissions
    - script:
        inputs:
        - content: |
            #!/bin/bash
            # Token has all permissions configured for the app
            echo "Token: $GITHUB_APPS_INSTALLATION_TOKEN"
```

---

## 7. Testing Contract

### 7.1 Test Scenarios

**Required Test Coverage**:

1. **YAML Hash Format**:
   - Single permission: `contents: read`
   - Multiple permissions: `contents: read`, `issues: write`
   - Verify token has correct permissions (GitHub API validation)

2. **JSON String Format** (backward compatibility):
   - Single permission: `'{"contents":"read"}'`
   - Multiple permissions: `'{"contents":"read","issues":"write"}'`
   - Verify identical behavior to YAML hash format

3. **Empty Permissions**:
   - Omitted: No `permissions` parameter in workflow
   - Empty string: `permissions: ''`
   - Verify token has all app permissions

4. **Invalid Inputs**:
   - Invalid JSON: `permissions: 'not-json'`
   - Malformed JSON: `permissions: '{contents:read}'`
   - Verify error message shows both format options

5. **Equivalence Testing**:
   - Generate token with YAML hash
   - Generate token with JSON string (same permissions)
   - Verify both tokens have identical permissions scope

### 7.2 Test Assertions

**For each valid input format**:
- Exit code is 0
- `GITHUB_APPS_INSTALLATION_TOKEN` is exported
- Token has correct permissions (verify via GitHub API)
- Success message displayed

**For invalid inputs**:
- Exit code is 1
- Error message references both YAML hash and JSON string formats
- Error message shows received value
- No token exported

**For backward compatibility**:
- JSON string format behavior unchanged from previous version
- Same validation, same errors, same success output

---

## Summary

| Aspect | Contract Details |
|--------|------------------|
| **Input Change** | `permissions` parameter now accepts YAML hash (recommended) and JSON string (legacy) |
| **Serialization** | Bitrise automatically converts YAML hash to JSON string (both formats identical) |
| **Validation** | JSON syntax validation with `jq empty` (applies to both formats) |
| **Error Messages** | Enhanced to reference both YAML hash and JSON string formats |
| **Output** | No changes - token export and usage identical to previous version |
| **Exit Codes** | No changes - 0 (success), 1 (validation), 2 (API), 3 (envman) |
| **Backward Compatibility** | Guaranteed - JSON string format continues to work identically |
| **Configuration** | step.yml updated with `is_expand: false` and dual-format documentation |

**Design Principle**: Minimal changes to existing contract, leveraging Bitrise's automatic serialization to avoid code complexity while providing better user experience.
