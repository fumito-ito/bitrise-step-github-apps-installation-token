# Bitrise Step I/O Contract: GitHub Apps Installation Token

**Feature**: 001-github-apps-token
**Step ID**: github-apps-installation-token
**Date**: 2025-10-28

## Overview

This contract defines the inputs, outputs, and behavior contract for the Bitrise step that generates GitHub Apps Installation Tokens.

---

## Inputs

All inputs are accessed as environment variables in step.sh.

### 1. `app_id`

**Description**: GitHub App ID (numeric identifier from GitHub App settings)

**Type**: String (numeric)

**Required**: Yes

**Default**: None

**Example**: `"123456"`

**Validation**:
- Must not be empty
- Must be numeric (only digits)

**Error if invalid**:
```
Error: App ID is required: set the app_id input parameter
```
or
```
Error: App ID must be numeric: received '<value>'
```

**step.yml Definition**:
```yaml
- app_id:
    opts:
      title: "GitHub App ID"
      summary: "The unique ID of your GitHub App"
      description: |
        The numeric ID of your GitHub App. You can find this in your
        GitHub App settings page under "About" → "App ID".
      is_required: true
      is_sensitive: false
```

---

### 2. `installation_id`

**Description**: GitHub App Installation ID (installation on specific account/org)

**Type**: String (numeric)

**Required**: Yes

**Default**: None

**Example**: `"789012"`

**Validation**:
- Must not be empty
- Must be numeric (only digits)

**Error if invalid**:
```
Error: Installation ID is required: set the installation_id input parameter
```
or
```
Error: Installation ID must be numeric: received '<value>'
```

**step.yml Definition**:
```yaml
- installation_id:
    opts:
      title: "GitHub App Installation ID"
      summary: "The ID of your app's installation"
      description: |
        The numeric ID of your GitHub App installation on a specific account or
        organization. You can find this in the installation URL or via the GitHub API.
      is_required: true
      is_sensitive: false
```

---

### 3. `private_pem`

**Description**: GitHub App private key in PEM format (RSA private key)

**Type**: String (multiline)

**Required**: Yes

**Default**: None

**Example**:
```
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA... (base64 encoded key)
...
-----END RSA PRIVATE KEY-----
```

**Validation**:
- Must not be empty
- Must contain "BEGIN" and "PRIVATE KEY" markers
- Must contain "END" and "PRIVATE KEY" markers
- Whitespace normalized before validation (trimmed, line breaks normalized)

**Security**:
- Marked as sensitive in step.yml (`is_sensitive: true`)
- Never logged to stdout/stderr
- Stored in temp file with 0600 permissions during JWT generation
- Temp file cleaned up on all exit paths

**Error if invalid**:
```
Error: Private PEM key is required: set the private_pem input parameter
```
or
```
Error: Invalid PEM format: ensure the key includes BEGIN/END RSA PRIVATE KEY markers
```

**step.yml Definition**:
```yaml
- private_pem:
    opts:
      title: "GitHub App Private Key (PEM)"
      summary: "The private key for your GitHub App"
      description: |
        The RSA private key for your GitHub App in PEM format. This is the .pem
        file you downloaded when creating the app. Include the full key with
        BEGIN/END markers.

        Store this as a Secret environment variable in Bitrise.
      is_required: true
      is_sensitive: true
      is_expand: true
```

---

### 4. `permissions` (Optional)

**Description**: Custom permissions to restrict the installation token scope (JSON object)

**Type**: String (JSON formatted)

**Required**: No

**Default**: Empty (uses app's configured permissions)

**Example**:
```json
{
  "contents": "read",
  "issues": "write",
  "pull_requests": "read"
}
```

**Validation**:
- If provided, must be valid JSON
- Passed through to GitHub API without format validation (per clarification Q3)
- GitHub API will validate permission names and access levels

**Behavior**:
- If omitted or empty: Token has all permissions configured for the app's installation
- If provided: Token has only the specified permissions (must be subset of app's permissions)

**Error if invalid**:
- JSON parsing error: Exit 1 with "Invalid permissions format: must be valid JSON"
- GitHub API rejects: Exit 2 with error from API (e.g., "Permission 'xyz' not available")

**step.yml Definition**:
```yaml
- permissions:
    opts:
      title: "Custom Permissions (Optional)"
      summary: "Restrict token to specific permissions"
      description: |
        Optional JSON object to restrict the installation token to specific permissions.
        Format: {"resource": "access_level", ...}
        Example: {"contents": "read", "issues": "write"}

        If omitted, the token will have all permissions configured for your app.
        Requested permissions must be a subset of your app's configured permissions.
      is_required: false
      is_sensitive: false
```

---

## Outputs

All outputs are exported via `envman add` to make them available to subsequent workflow steps.

### 1. `GITHUB_APPS_INSTALLATION_TOKEN`

**Description**: The generated GitHub Apps Installation Access Token

**Type**: String

**Format**: `ghs_` prefix + alphanumeric string

**Length**: ~40-60 characters

**Lifetime**: 1 hour from generation

**Usage**: Bearer token for GitHub API requests in subsequent workflow steps

**Example Value**: `"ghs_16C7e42F292c6912E7710c838347Ae178B4a"`

**Export Method**:
```bash
echo "$token" | envman add --key GITHUB_APPS_INSTALLATION_TOKEN
```

**Validation**:
- Token must be non-empty
- envman exit code must be 0 (per clarification Q4)

**Error if export fails**:
```
Error: Failed to export token to environment: envman returned non-zero exit code
```

**Security**:
- Never logged to stdout/stderr
- Treated as sensitive data throughout step execution

**step.yml Definition**:
```yaml
outputs:
  - GITHUB_APPS_INSTALLATION_TOKEN:
      opts:
        title: "GitHub Apps Installation Token"
        summary: "The generated installation access token"
        description: |
          The installation access token for your GitHub App. This token can be
          used to authenticate API requests as the GitHub App installation.

          Valid for 1 hour from generation. Use in subsequent steps with:
          curl -H "Authorization: Bearer $GITHUB_APPS_INSTALLATION_TOKEN" ...
        is_sensitive: true
```

---

## Exit Codes

The step uses specific exit codes to indicate different failure modes:

| Exit Code | Meaning | Examples |
|-----------|---------|----------|
| `0` | Success | Token generated and exported successfully |
| `1` | Input validation failure | Missing app_id, invalid PEM format, malformed JSON |
| `2` | GitHub API error | 401 (bad credentials), 404 (installation not found), 403 (permission denied), network error |
| `3` | envman export failure | envman command failed, token not exported |

**Usage in workflows**:
- Bitrise registers exit code 0 as "step successful"
- Any non-zero exit code registers as "step failed" and stops workflow (unless step marked skippable)

---

## Behavior Contract

### Input Validation (FR-005)

**Order of validation**:
1. Check `app_id` is non-empty and numeric
2. Check `installation_id` is non-empty and numeric
3. Check `private_pem` is non-empty
4. Normalize `private_pem` whitespace (trim, normalize line breaks)
5. Validate `private_pem` has BEGIN/END markers
6. If `permissions` provided, validate it's valid JSON

**All validation happens before any API calls or sensitive operations.**

### PEM Key Normalization (FR-015, Clarification Q2)

**Applied automatically before validation**:
- Trim leading whitespace
- Trim trailing whitespace
- Normalize line endings (CRLF → LF)
- Remove extra blank lines

**Purpose**: Handle copy/paste artifacts without compromising security

### JWT Generation (FR-006)

**Claims**:
- `iat`: Current Unix timestamp minus 60 seconds (clock drift protection)
- `exp`: Current Unix timestamp plus 600 seconds (10-minute expiration)
- `iss`: Value of `app_id` input

**Algorithm**: RS256 (RSA Signature with SHA-256)

**Signing**: Uses normalized `private_pem` key

### API Call with Retry (FR-007, FR-014, Clarification Q1)

**Endpoint**: `POST https://api.github.com/app/installations/{installation_id}/access_tokens`

**Headers**: Accept, Authorization (Bearer JWT), X-GitHub-Api-Version, User-Agent

**Body**: Only if `permissions` input provided (passed through without validation)

**Retry Logic**:
- First attempt fails with HTTP 503 or 429 → Wait 5 seconds → Retry once
- Second attempt fails → Exit 2 with error message
- Other HTTP errors (401, 404, 403, 422) → No retry, exit 2 immediately

### Token Export (FR-008, Clarification Q4)

**Method**: `envman add --key GITHUB_APPS_INSTALLATION_TOKEN`

**Verification**: Check envman exit code after export

**Failure handling**: If envman returns non-zero, exit 3 with error message

### Logging and Security (FR-009)

**What is logged**:
- Step start message
- Validation status messages
- API call status (endpoint, HTTP code)
- Token expiration time (from API response)
- Success confirmation message

**What is NEVER logged**:
- `private_pem` input value
- Normalized PEM content
- JWT value
- `Authorization: Bearer <JWT>` header
- `token` value from API response
- envman command with token value

**Implementation**: Use `set +x` around sensitive operations

### Cleanup (FR-011)

**Resources to clean**:
- Temporary PEM file (created with mktemp, chmod 0600)

**Cleanup trigger**: `trap cleanup EXIT ERR INT TERM`

**Cleanup guarantee**: Runs on all exit paths (success, error, interrupt)

---

## Example Usage in bitrise.yml

### Basic Usage

```yaml
workflows:
  deploy:
    steps:
    - github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
    - script:
        inputs:
        - content: |
            #!/bin/bash
            curl -H "Authorization: Bearer $GITHUB_APPS_INSTALLATION_TOKEN" \
              https://api.github.com/repos/owner/repo/issues
```

### With Custom Permissions

```yaml
workflows:
  build:
    steps:
    - github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
        - permissions: '{"contents": "read", "checks": "write"}'
    - script:
        inputs:
        - content: |
            #!/bin/bash
            # Token has only contents:read and checks:write permissions
            echo "Token: $GITHUB_APPS_INSTALLATION_TOKEN"
```

### Error Handling

```yaml
workflows:
  test:
    steps:
    - github-apps-installation-token:
        is_skippable: false  # Fail workflow if token generation fails
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
    - script:
        run_if: .IsCI  # Only runs if previous step succeeded
        inputs:
        - content: |
            #!/bin/bash
            # This only runs if token was generated successfully
            curl -H "Authorization: Bearer $GITHUB_APPS_INSTALLATION_TOKEN" \
              https://api.github.com/installation/repositories
```

---

## Testing Contract

### Test Scenarios (from spec.md)

**User Story 1 - Basic Token Generation (P1)**:
- Input: Valid app_id, installation_id, private_pem
- Expected: GITHUB_APPS_INSTALLATION_TOKEN exported, exit 0
- Test: `bitrise run test` with `.bitrise.secrets.yml` containing real credentials

**User Story 2 - Custom Permissions (P2)**:
- Input: Valid credentials + permissions='{"contents":"read"}'
- Expected: Token generated with only contents:read permission
- Test: Verify token permissions by calling GitHub API

**User Story 3 - Error Handling (P3)**:
- Input: Missing app_id
- Expected: Error message "App ID is required", exit 1
- Test: `bitrise run test-missing-app-id`

**Edge Cases**:
- PEM with extra whitespace → Normalized and accepted
- GitHub API returns 503 → Wait 5s, retry, then fail if still 503
- Invalid permissions format → GitHub API error relayed to user
- envman fails → Exit 3 with clear error

---

## Version Compatibility

**Minimum Bitrise CLI**: 1.x (any version with envman support)

**Required Tools** (documented in step.yml deps):
- openssl 1.0.2+
- curl 7.x+
- jq 1.5+
- envman (Bitrise-provided)
- bash 4.x+

**Bitrise Stacks**: Compatible with all Linux and macOS stacks

---

## References

- [Bitrise Step Development Guideline](https://github.com/bitrise-io/bitrise/blob/master/_docs/step-development-guideline.md)
- [Bitrise step.yml Format Spec](https://github.com/bitrise-io/bitrise/blob/master/_docs/bitrise-yml-format-spec.md)
- [envman Documentation](https://github.com/bitrise-io/envman)
- Feature Specification: [spec.md](../spec.md)
