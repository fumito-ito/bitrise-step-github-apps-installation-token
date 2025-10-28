# Data Model: GitHub Apps Installation Token Generator

**Feature**: 001-github-apps-token
**Date**: 2025-10-28
**Status**: Complete

## Overview

This feature does not have a persistent data model as it is a **stateless transformation operation**. All entities are ephemeral runtime objects that exist only during step execution. This document describes the data transformations and entity relationships during the token generation flow.

---

## Entity Flow Diagram

```
Input (Environment Variables)
    ↓
GitHub App Credentials
    ↓
JWT (JSON Web Token)
    ↓
API Request
    ↓
Installation Access Token
    ↓
Output (Environment Variable)
```

---

## Runtime Entities

### 1. GitHub App Credentials (Input)

**Source**: Step inputs (environment variables)

**Attributes**:
- `app_id` (string, numeric): GitHub App ID
  - Format: Numeric string (e.g., "123456")
  - Required: Yes
  - Validation: Non-empty, numeric

- `installation_id` (string, numeric): Installation ID
  - Format: Numeric string (e.g., "789012")
  - Required: Yes
  - Validation: Non-empty, numeric

- `private_pem` (string, multiline): RSA private key in PEM format
  - Format: Multi-line string with BEGIN/END markers
  - Required: Yes
  - Validation: Contains "BEGIN.*PRIVATE KEY" and "END.*PRIVATE KEY"
  - Transformation: Whitespace normalization (trim, normalize line breaks)
  - Security: Never logged, stored in temp file with 0600 permissions

- `permissions` (string, optional): JSON object defining permissions
  - Format: JSON string or empty
  - Required: No
  - Default: null (uses app's configured permissions)
  - Validation: Valid JSON if provided, passed through to GitHub API
  - Example: `{"contents": "read", "issues": "write"}`

**Lifecycle**: Loaded at step start, validated before use, PEM cleaned up on exit

---

### 2. JWT (JSON Web Token)

**Source**: Generated from GitHub App credentials

**Structure**:
```
header.payload.signature
```

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
  "iss": "<app_id>"
}
```

**Signature** (binary, base64url-encoded):
- Algorithm: RS256 (RSA Signature with SHA-256)
- Input: `encoded_header.encoded_payload`
- Key: `private_pem`
- Output: Base64url-encoded signature

**Attributes**:
- Total length: ~800-1200 characters (typical)
- Expiration: 10 minutes from generation
- Security: Never logged, used only in Authorization header

**Lifecycle**: Generated immediately before API call, discarded after use

---

### 3. API Request

**Purpose**: Exchange JWT for installation access token

**Structure**:
```http
POST /app/installations/{installation_id}/access_tokens HTTP/1.1
Host: api.github.com
Accept: application/vnd.github+json
Authorization: Bearer <JWT>
X-GitHub-Api-Version: 2022-11-28
User-Agent: bitrise-step-github-apps-installation-token
Content-Type: application/json

{
  "permissions": { ... }  // Optional, only if provided
}
```

**Request Body** (optional):
- Present only if `permissions` input provided
- Format: JSON object with permission scopes
- Example:
  ```json
  {
    "permissions": {
      "contents": "read",
      "issues": "write"
    }
  }
  ```

**Lifecycle**: Created immediately before API call, discarded after response

---

### 4. API Response

**Success Response** (HTTP 200/201):
```json
{
  "token": "ghs_16C7e42F292c6912E7710c838347Ae178B4a",
  "expires_at": "2025-10-28T12:00:00Z",
  "permissions": {
    "contents": "read",
    "issues": "write"
  },
  "repositories": [
    {
      "id": 1296269,
      "name": "Hello-World",
      "full_name": "octocat/Hello-World"
    }
  ]
}
```

**Error Response** (HTTP 4xx/5xx):
```json
{
  "message": "Not Found",
  "documentation_url": "https://docs.github.com/rest/..."
}
```

**Extracted Data**:
- `token` (string): The installation access token
  - Format: `ghs_` prefix + alphanumeric string
  - Length: ~40-60 characters
  - Security: Never logged, passed directly to envman
- `expires_at` (string, ISO 8601): Token expiration time
  - Always 1 hour from generation
  - Logged for user awareness (non-sensitive)

**Lifecycle**: Received from API, token extracted and exported, response discarded

---

### 5. Installation Access Token (Output)

**Source**: Extracted from API response

**Attributes**:
- `token` (string): The access token value
  - Format: `ghs_` prefix + alphanumeric
  - Length: ~40-60 characters
  - Expiration: 1 hour from generation
  - Permissions: As requested or app default
  - Security: Never logged, exported via envman

**Export**:
- Environment variable name: `GITHUB_APPS_INSTALLATION_TOKEN`
- Method: `envman add --key GITHUB_APPS_INSTALLATION_TOKEN`
- Validation: envman exit code checked
- Availability: Immediately available to subsequent workflow steps

**Lifecycle**: Extracted from API response, exported to environment, available until workflow completes or token expires

---

## Data Transformations

### Transformation 1: Credentials → JWT

**Input**: `app_id`, `private_pem`
**Output**: `JWT` string
**Process**:
1. Normalize `private_pem` (trim whitespace, normalize line breaks)
2. Validate PEM format (BEGIN/END markers)
3. Generate timestamp: `iat = now() - 60`, `exp = now() + 600`
4. Create header JSON, base64url encode
5. Create payload JSON with `iat`, `exp`, `iss=app_id`, base64url encode
6. Concatenate: `encoded_header.encoded_payload`
7. Sign with openssl using `private_pem`, base64url encode signature
8. Concatenate: `encoded_header.encoded_payload.encoded_signature`

**Security**: Performed with `set +x` (no logging), temp file with 0600 permissions

---

### Transformation 2: JWT + Installation ID → API Request

**Input**: `JWT`, `installation_id`, `permissions` (optional)
**Output**: HTTP request to GitHub API
**Process**:
1. Construct URL: `https://api.github.com/app/installations/{installation_id}/access_tokens`
2. Set headers: Accept, Authorization (Bearer JWT), X-GitHub-Api-Version, User-Agent
3. If `permissions` provided, set body: `{"permissions": {...}}`
4. Make POST request with curl
5. Capture response body and HTTP status code

**Retry Logic**: If HTTP 503/429, wait 5 seconds and retry once

---

### Transformation 3: API Response → Installation Token

**Input**: API response JSON
**Output**: `token` string
**Process**:
1. Parse response with jq: `jq -r '.token'`
2. Validate token is non-empty
3. Extract `expires_at` for logging (optional)
4. Export token via envman
5. Verify envman exit code

**Error Handling**: Parse error message from response if HTTP != 200/201

---

## State Transitions

This feature has no state machine as it's a stateless operation. However, the execution flow has distinct phases:

```
[START]
   ↓
[VALIDATE_INPUTS] → [ERROR: Exit 1] if validation fails
   ↓
[NORMALIZE_PEM]
   ↓
[GENERATE_JWT] → [ERROR: Exit 1] if signing fails
   ↓
[CALL_API_ATTEMPT_1]
   ↓
   ├─[SUCCESS: HTTP 200/201] → [EXTRACT_TOKEN]
   ├─[RETRYABLE: HTTP 503/429] → [WAIT_5S] → [CALL_API_ATTEMPT_2]
   └─[ERROR: HTTP 4xx/other] → [ERROR: Exit 2]
   ↓
[EXPORT_TOKEN] → [ERROR: Exit 3] if envman fails
   ↓
[CLEANUP] (via trap, always runs)
   ↓
[SUCCESS: Exit 0]
```

---

## Validation Rules

### Input Validation (FR-005)

| Field | Rule | Error Message |
|-------|------|---------------|
| `app_id` | Non-empty | "App ID is required" |
| `app_id` | Numeric | "App ID must be numeric" |
| `installation_id` | Non-empty | "Installation ID is required" |
| `installation_id` | Numeric | "Installation ID must be numeric" |
| `private_pem` | Non-empty | "Private PEM key is required" |
| `private_pem` | Contains BEGIN marker | "Invalid PEM format: ensure key includes BEGIN/END markers" |
| `private_pem` | Contains END marker | "Invalid PEM format: ensure key includes BEGIN/END markers" |
| `permissions` (if provided) | Valid JSON | "Invalid permissions format: must be valid JSON" |

### Output Validation

| Field | Rule | Action if fails |
|-------|------|-----------------|
| `token` from API | Non-empty | Exit 2 with "GitHub API returned empty token" |
| envman exit code | == 0 | Exit 3 with "Failed to export token to environment" |

---

## Security Considerations

### Sensitive Data (Never Logged)

- `private_pem`: Input PEM key
- Normalized PEM content
- Temp file path and content
- JWT header.payload.signature
- `Authorization: Bearer <JWT>` header
- `token` value from API response
- envman command with token

### Non-Sensitive Data (May be Logged)

- `app_id` (public identifier)
- `installation_id` (public identifier)
- API endpoint URL
- HTTP status codes
- API error messages (from `message` field)
- `expires_at` timestamp
- Permissions structure (keys only, not token)

### Cleanup Requirements (FR-011)

- Temp PEM file: Deleted via trap on EXIT/ERR/INT/TERM
- JWT string: Cleared from memory (bash variable scope)
- API response: Cleared from memory after token extraction

---

## Summary

This is a **stateless data transformation pipeline** with no persistent storage:

1. **Input**: GitHub App credentials (env vars)
2. **Transform 1**: Credentials → JWT (in-memory, 10-min lifetime)
3. **Transform 2**: JWT → API Request (HTTP, immediate)
4. **Transform 3**: API Response → Installation Token (extracted)
5. **Output**: Installation token (env var via envman, 1-hour lifetime)

All intermediate data is ephemeral and cleaned up. Security is maintained through:
- No logging of sensitive values
- Temp files with restrictive permissions
- Guaranteed cleanup via trap handlers
- Validation at each transformation step

**No persistent data model required.**
