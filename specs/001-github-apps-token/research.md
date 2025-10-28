# Technical Research: GitHub Apps Installation Token Generator

**Feature**: 001-github-apps-token
**Date**: 2025-10-28
**Status**: Complete

## Purpose

This document captures research findings and technical decisions for implementing the GitHub Apps Installation Token generator as a Bitrise step. All NEEDS CLARIFICATION items from Technical Context have been resolved.

---

## 1. JWT Generation in Bash/Shell

### Decision

Use openssl for RS256 JWT signing with bash-native base64url encoding.

### Implementation Approach

**JWT Structure**: `header.payload.signature`

**Header** (JSON, base64url-encoded):
```json
{
  "alg": "RS256",
  "typ": "JWT"
}
```

**Payload** (JSON, base64url-encoded):
```json
{
  "iat": <unix_timestamp_minus_60>,
  "exp": <unix_timestamp_plus_600>,
  "iss": "<github_app_id>"
}
```

**Timing Requirements**:
- `iat` (Issued At): Current time MINUS 60 seconds (protects against clock drift)
- `exp` (Expires At): Current time PLUS 600 seconds (10 minutes max, per GitHub requirement)
- Use `date +%s` for Unix timestamps in bash

**Signing Process**:
1. Create header and payload JSON
2. Base64url encode each (base64 + remove padding + replace +/ with -_)
3. Concatenate: `encoded_header.encoded_payload`
4. Sign with openssl: `echo -n "$data" | openssl dgst -sha256 -sign <pem_file> | base64`
5. Base64url encode signature
6. Final JWT: `encoded_header.encoded_payload.encoded_signature`

**Base64url Encoding Function**:
```bash
base64url_encode() {
  # Remove newlines, replace +/ with -_, remove padding =
  base64 | tr -d '\n' | tr '+/' '-_' | tr -d '='
}
```

**PEM Key Handling**:
- Write normalized PEM to temp file created with `mktemp`
- Immediately `chmod 0600 <temp_file>`
- Use `trap` to ensure cleanup on EXIT/ERR/INT signals

### Rationale

- openssl is ubiquitous on Unix systems (Linux, macOS)
- RS256 is the only accepted algorithm for GitHub Apps JWT
- Base64url encoding (RFC 4648 §5) required for JWT spec compliance
- Temp file necessary because openssl -sign requires file input for private key

### Alternatives Considered

- **jq with jwt libraries**: Not available by default, requires installation
- **Python/Ruby scripts**: Adds language dependency, violates shell-first principle
- **Pre-built JWT CLI tools**: Not standard, installation overhead

### References

- GitHub Docs: [Generating a JWT for a GitHub App](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-json-web-token-jwt-for-a-github-app)
- JWT Spec: RFC 7519
- Base64url: RFC 4648 Section 5

---

## 2. GitHub API Integration

### Decision

Use curl with explicit headers and retry logic for rate limits/transient failures.

### API Contract

**Endpoint**: `POST https://api.github.com/app/installations/{installation_id}/access_tokens`

**Required Headers**:
```
Accept: application/vnd.github+json
Authorization: Bearer <JWT>
X-GitHub-Api-Version: 2022-11-28
User-Agent: bitrise-step-github-apps-installation-token
```

**Request Body** (optional, for custom permissions):
```json
{
  "permissions": {
    "contents": "read",
    "issues": "write"
  }
}
```

**Success Response** (200 OK):
```json
{
  "token": "ghs_16C7e42F292c6912E7710c838347Ae178B4a",
  "expires_at": "2025-10-28T12:00:00Z",
  "permissions": { ... },
  "repositories": [ ... ]
}
```

**Error Responses**:
- `401 Unauthorized`: Invalid JWT, expired JWT, or wrong App ID
- `404 Not Found`: Installation ID doesn't exist or app not installed
- `403 Forbidden`: Permissions requested not granted to app
- `422 Unprocessable Entity`: Invalid permissions format
- `503 Service Unavailable`: GitHub API temporarily unavailable (retry)

**Rate Limiting**:
- HTTP 429 or 503 may indicate rate limiting
- Retry-After header may be present
- Our approach: wait 5 seconds, retry once (per clarification Q1)

### Implementation Pattern

```bash
# First attempt
response=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer ${jwt}" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  -H "User-Agent: bitrise-step-github-apps-installation-token" \
  -d "${permissions_json}" \
  "https://api.github.com/app/installations/${installation_id}/access_tokens")

http_code=$(echo "$response" | tail -n1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" != "200" ] && [ "$http_code" != "201" ]; then
  # Check for retryable errors (503, 429)
  if [ "$http_code" = "503" ] || [ "$http_code" = "429" ]; then
    echo "Rate limited or API unavailable, waiting 5 seconds..."
    sleep 5
    # Retry once
    response=$(curl ...)
  fi
fi

# Extract token with jq
token=$(echo "$body" | jq -r '.token')
```

### Rationale

- curl is universally available and reliable for HTTP requests
- Explicit headers ensure API version compatibility
- User-Agent identifies the step for GitHub's telemetry
- Single retry with 5-second delay balances reliability vs execution time
- jq for JSON parsing is lightweight and handles edge cases

### Alternatives Considered

- **gh CLI**: Requires installation, overkill for single API call
- **wget**: Less flexible header handling than curl
- **Multiple retries with exponential backoff**: Excessive for typical transient failures

### References

- GitHub REST API: [Create an installation access token](https://docs.github.com/en/rest/apps/apps#create-an-installation-access-token-for-an-app)
- HTTP Status Codes: RFC 7231

---

## 3. Bitrise Step Best Practices

### Decision

Follow Bitrise Step Development Guidelines for input/output conventions and testing patterns.

### Input/Output Conventions

**Input Variables** (from step.yml, accessed as environment variables):
- `app_id`: GitHub App ID (numeric string)
- `installation_id`: Installation ID (numeric string)
- `private_pem`: GitHub App private PEM key (multiline string, secret)
- `permissions`: Optional JSON string for custom permissions

**Environment Variable Naming**:
- Bitrise auto-prefixes with step name, but we define base names in step.yml
- Use lowercase with underscores: `app_id` not `appId` or `APP_ID`

**Output Variables** (exported via envman):
- `GITHUB_APPS_INSTALLATION_TOKEN`: The generated installation access token
- Use UPPERCASE for output variables (Bitrise convention)

**envman Export Pattern**:
```bash
# Pipe approach for complex values (avoids escaping issues)
echo "$token" | envman add --key GITHUB_APPS_INSTALLATION_TOKEN

# Verify envman exit code (per clarification Q4)
if [ $? -ne 0 ]; then
  echo "Error: Failed to export token to environment"
  exit 3
fi
```

### Error Messages and Exit Codes

**Format**: `Error: <what happened>: <actionable guidance>`

Examples:
- `Error: App ID is required: set the app_id input parameter`
- `Error: Invalid PEM format: ensure the key includes BEGIN/END RSA PRIVATE KEY markers`
- `Error: GitHub API returned 404: verify installation exists for this App ID`

**Exit Codes**:
- `0`: Success
- `1`: Input validation failure
- `2`: GitHub API error
- `3`: envman export failure

### Cleanup and Trap Handlers

```bash
#!/bin/bash
set -e  # Exit on error

# Temp file for PEM key
PEM_TEMP_FILE=""

cleanup() {
  if [ -n "$PEM_TEMP_FILE" ] && [ -f "$PEM_TEMP_FILE" ]; then
    rm -f "$PEM_TEMP_FILE"
  fi
}

# Trap all exit scenarios
trap cleanup EXIT ERR INT TERM

# Create temp file
PEM_TEMP_FILE=$(mktemp)
chmod 0600 "$PEM_TEMP_FILE"
```

### Testing Pattern (bitrise.yml)

```yaml
workflows:
  test:
    steps:
    - path::./:
        title: Test - Valid Credentials
        inputs:
        - app_id: $TEST_APP_ID
        - installation_id: $TEST_INSTALLATION_ID
        - private_pem: $TEST_PRIVATE_PEM
    - script:
        inputs:
        - content: |
            #!/bin/bash
            if [ -z "$GITHUB_APPS_INSTALLATION_TOKEN" ]; then
              echo "Error: Token not generated"
              exit 1
            fi
            echo "Success: Token generated"
```

**Local Testing**:
- Create `.bitrise.secrets.yml` (git-ignored) with real credentials
- Run `bitrise run test`
- Verify token generation and export

### Rationale

- Following Bitrise conventions ensures compatibility with Step Library
- Clear error messages reduce support burden (aligns with SC-003)
- Trap handlers ensure cleanup even on unexpected failures (FR-011)
- Testing via bitrise.yml validates real-world usage

### References

- [Bitrise Step Development Guideline](https://github.com/bitrise-io/bitrise/blob/master/_docs/step-development-guideline.md)
- [envman documentation](https://github.com/bitrise-io/envman)

---

## 4. Security Implementation

### Decision

Implement defense-in-depth: input normalization, no logging of secrets, secure temp files, guaranteed cleanup.

### PEM Key Normalization

**Purpose**: Handle copy/paste artifacts without compromising security (clarification Q2)

**Approach**:
```bash
normalize_pem() {
  local pem="$1"
  # Trim leading/trailing whitespace
  pem=$(echo "$pem" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
  # Normalize line endings (CRLF -> LF)
  pem=$(echo "$pem" | tr -d '\r')
  echo "$pem"
}

# Validate structure after normalization
if ! echo "$normalized_pem" | grep -q "BEGIN.*PRIVATE KEY"; then
  echo "Error: Invalid PEM format: ensure the key includes BEGIN/END markers"
  exit 1
fi
```

### Suppressing Sensitive Data in Logs

**set +x during sensitive operations**:
```bash
#!/bin/bash
set -ex  # Debug mode ON initially

# Input validation (non-sensitive)
[ -z "$app_id" ] && echo "Error: App ID is required" && exit 1

# Disable debug output before handling secrets
set +x

# JWT generation (sensitive)
jwt=$(generate_jwt "$app_id" "$normalized_pem")

# API call (sensitive - has JWT in header)
response=$(curl ...)

# Re-enable if needed for debugging non-sensitive operations
# set -x

# Export token (sensitive)
echo "$token" | envman add --key GITHUB_APPS_INSTALLATION_TOKEN
```

### Temp File Security

```bash
# Create with restrictive permissions immediately
PEM_TEMP_FILE=$(mktemp)
chmod 0600 "$PEM_TEMP_FILE"  # Owner read/write only

# Write PEM content
echo "$normalized_pem" > "$PEM_TEMP_FILE"

# Use for signing
signature=$(echo -n "$data" | openssl dgst -sha256 -sign "$PEM_TEMP_FILE" | base64)

# Cleanup happens via trap (even on error)
```

### Cleanup Guarantees

**Trap all signals**:
```bash
trap cleanup EXIT     # Normal exit
trap cleanup ERR      # Error exit (with set -e)
trap cleanup INT      # Ctrl+C
trap cleanup TERM     # kill command
```

**Cleanup function**:
```bash
cleanup() {
  if [ -n "$PEM_TEMP_FILE" ] && [ -f "$PEM_TEMP_FILE" ]; then
    # Shred if available (defense in depth), otherwise rm
    if command -v shred >/dev/null 2>&1; then
      shred -u "$PEM_TEMP_FILE" 2>/dev/null || rm -f "$PEM_TEMP_FILE"
    else
      rm -f "$PEM_TEMP_FILE"
    fi
  fi
}
```

### Rationale

- Normalization improves UX without security tradeoff (FR-015)
- set +x prevents leaking secrets in debug logs (FR-009)
- 0600 permissions ensure only process owner can read temp files (FR-010)
- Multiple trap signals guarantee cleanup in all scenarios (FR-011)
- shred (when available) provides additional security by overwriting file content

### Compliance with Constitution

- ✅ Principle III: All security requirements addressed
- ✅ FR-009: No sensitive data logged (set +x)
- ✅ FR-010: 0600 permissions on temp files
- ✅ FR-011: Cleanup on all exit paths (trap handlers)
- ✅ FR-015: PEM normalization before validation

### References

- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- Bash Manual: `trap` command

---

## 5. Dependency Versions

### Decision

Rely on versions available in standard Bitrise stacks, document minimum requirements in step.yml.

### Required Tools and Versions

**openssl**:
- Minimum: 1.0.2 (for modern key formats)
- Available: Pre-installed on all Bitrise stacks (Linux, macOS)
- Usage: JWT signing with RS256

**curl**:
- Minimum: 7.x (for modern TLS and header support)
- Available: Pre-installed on all Bitrise stacks
- Usage: GitHub API calls

**jq**:
- Minimum: 1.5 (for `.token` accessor and `-r` raw output)
- Available: Pre-installed on all Bitrise stacks
- Usage: JSON parsing of API responses

**envman**:
- Version: Bitrise-managed (auto-installed with `bitrise setup`)
- Available: Guaranteed in Bitrise environment
- Usage: Environment variable export

**bash**:
- Minimum: 4.x (for modern array handling and string ops)
- Available: Default on all Bitrise stacks
- Usage: Script execution

### Declaration in step.yml

```yaml
deps:
  apt_get:
  - name: openssl
  - name: curl
  - name: jq
  brew:
  - name: openssl
  - name: curl
  - name: jq
```

**Note**: These are documentation/validation entries. In practice, all are pre-installed on Bitrise stacks, so installation won't actually occur.

### Validation at Runtime

Add tool availability check at start of step.sh:

```bash
# Validate required tools
for tool in openssl curl jq envman; do
  if ! command -v $tool >/dev/null 2>&1; then
    echo "Error: Required tool '$tool' not found"
    exit 1
  fi
done
```

### Rationale

- Documenting deps in step.yml follows Bitrise best practices
- Runtime validation provides clear error if environment is non-standard
- All tools are POSIX/Unix standard, no proprietary dependencies
- Version requirements are conservative (widely available versions)

---

## Summary of Decisions

| Area | Decision | Rationale |
|------|----------|-----------|
| JWT Generation | openssl + bash base64url | Universal availability, no extra deps |
| GitHub API | curl with retry logic | Standard tool, explicit error handling |
| JSON Parsing | jq | Lightweight, handles edge cases |
| PEM Handling | Normalize then validate | Better UX, maintains security |
| Logging | set +x around secrets | Prevents accidental leaks |
| Temp Files | mktemp + chmod 0600 | Secure by default |
| Cleanup | trap EXIT/ERR/INT/TERM | Guaranteed cleanup |
| Testing | bitrise.yml workflows | Real-world validation |
| Dependencies | Rely on Bitrise stacks | No installation overhead |

All Technical Context items resolved - ready for Phase 1 (Design).
