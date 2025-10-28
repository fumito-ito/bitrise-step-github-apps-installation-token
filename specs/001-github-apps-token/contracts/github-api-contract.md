# GitHub REST API Contract: Installation Access Tokens

**Feature**: 001-github-apps-token
**API Version**: 2022-11-28
**Date**: 2025-10-28

## Endpoint

```
POST https://api.github.com/app/installations/{installation_id}/access_tokens
```

**Path Parameters**:
- `installation_id` (integer, required): The unique identifier of the installation

---

## Authentication

**Type**: Bearer Token (JWT)

**Header**:
```
Authorization: Bearer <JWT>
```

**JWT Requirements**:
- Algorithm: RS256
- Claims:
  - `iat` (issued at): Current time minus 60 seconds (Unix timestamp)
  - `exp` (expires at): Current time plus 600 seconds max (Unix timestamp)
  - `iss` (issuer): GitHub App ID
- Signature: Signed with GitHub App private key (PEM format, RSA)

---

## Request

### Required Headers

```http
Accept: application/vnd.github+json
Authorization: Bearer <JWT>
X-GitHub-Api-Version: 2022-11-28
User-Agent: bitrise-step-github-apps-installation-token
```

**Header Descriptions**:
- `Accept`: Specifies GitHub API JSON format
- `Authorization`: JWT for GitHub App authentication
- `X-GitHub-Api-Version`: API version for stability
- `User-Agent`: Identifies the client (step name)

### Request Body (Optional)

**Content-Type**: `application/json`

**Schema**:
```json
{
  "repositories": [<repository_names>],          // Optional
  "repository_ids": [<repository_ids>],          // Optional
  "permissions": {<permission_object>}           // Optional
}
```

**Fields**:

- `repositories` (array of strings, optional): List of repository names to restrict access
  - Maximum: 500 repositories
  - Mutually exclusive with `repository_ids`
  - Example: `["Hello-World", "my-repo"]`

- `repository_ids` (array of integers, optional): List of repository IDs to restrict access
  - Maximum: 500 repositories
  - Mutually exclusive with `repositories`
  - Example: `[1296269, 1296270]`

- `permissions` (object, optional): Custom permissions for the token
  - Keys: Permission names (e.g., "contents", "issues", "pull_requests")
  - Values: Access level ("read" or "write")
  - Cannot exceed app's configured permissions
  - Example:
    ```json
    {
      "contents": "read",
      "issues": "write",
      "pull_requests": "read"
    }
    ```

**Note**: If no body is provided, the token inherits all permissions configured for the app's installation.

### Example Requests

**Minimal Request** (no custom permissions):
```http
POST /app/installations/12345678/access_tokens HTTP/1.1
Host: api.github.com
Accept: application/vnd.github+json
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
X-GitHub-Api-Version: 2022-11-28
User-Agent: bitrise-step-github-apps-installation-token
```

**Request with Custom Permissions**:
```http
POST /app/installations/12345678/access_tokens HTTP/1.1
Host: api.github.com
Accept: application/vnd.github+json
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...
X-GitHub-Api-Version: 2022-11-28
User-Agent: bitrise-step-github-apps-installation-token
Content-Type: application/json

{
  "permissions": {
    "contents": "read",
    "issues": "write"
  }
}
```

---

## Response

### Success Response

**HTTP Status**: `201 Created` or `200 OK`

**Schema**:
```json
{
  "token": "<installation_access_token>",
  "expires_at": "<ISO_8601_timestamp>",
  "permissions": {<permission_object>},
  "repository_selection": "<selection_type>",
  "repositories": [<repository_objects>]
}
```

**Fields**:

- `token` (string, required): The installation access token
  - Format: `ghs_` prefix + alphanumeric string
  - Length: ~40-60 characters
  - Lifetime: 1 hour from generation
  - Usage: Bearer token for GitHub API requests

- `expires_at` (string, required): Token expiration timestamp
  - Format: ISO 8601 (e.g., "2025-10-28T12:00:00Z")
  - Always 1 hour from generation

- `permissions` (object, required): Token permissions
  - Keys: Permission names
  - Values: Access levels ("read" or "write")
  - Reflects requested permissions or app defaults

- `repository_selection` (string, required): Scope of repository access
  - Values: "all" or "selected"

- `repositories` (array of objects, optional): List of accessible repositories
  - Present if `repository_selection` is "selected"
  - Each object contains: `id`, `name`, `full_name`, etc.

**Example Success Response**:
```json
{
  "token": "ghs_16C7e42F292c6912E7710c838347Ae178B4a",
  "expires_at": "2025-10-28T12:00:00Z",
  "permissions": {
    "contents": "read",
    "issues": "write",
    "metadata": "read"
  },
  "repository_selection": "all",
  "repositories": []
}
```

### Error Responses

#### 401 Unauthorized

**Cause**: Invalid or expired JWT, wrong App ID

**Response Body**:
```json
{
  "message": "Bad credentials",
  "documentation_url": "https://docs.github.com/rest"
}
```

**Step Action**: Exit with code 2, display error:
```
Error: GitHub authentication failed: verify App ID and private PEM key are correct
```

---

#### 404 Not Found

**Cause**: Installation ID doesn't exist or app not installed there

**Response Body**:
```json
{
  "message": "Not Found",
  "documentation_url": "https://docs.github.com/rest"
}
```

**Step Action**: Exit with code 2, display error:
```
Error: Installation ID not found: verify the installation exists and the App ID is correct
```

---

#### 403 Forbidden

**Cause**: Requested permissions not granted to app

**Response Body**:
```json
{
  "message": "Resource not accessible by integration",
  "documentation_url": "https://docs.github.com/rest"
}
```

**Step Action**: Exit with code 2, display error with context:
```
Error: GitHub API rejected permissions: <permissions> - verify the app has these permissions configured
```

---

#### 422 Unprocessable Entity

**Cause**: Invalid request body format (malformed permissions, too many repos)

**Response Body**:
```json
{
  "message": "Validation Failed",
  "errors": [
    {
      "resource": "Installation",
      "code": "invalid",
      "field": "permissions"
    }
  ],
  "documentation_url": "https://docs.github.com/rest"
}
```

**Step Action**: Exit with code 2, display error:
```
Error: Invalid permissions format: <error details from GitHub>
```

---

#### 429 Too Many Requests

**Cause**: Rate limit exceeded

**Response Headers**:
```
X-RateLimit-Limit: 5000
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1633024800
Retry-After: 60
```

**Response Body**:
```json
{
  "message": "API rate limit exceeded",
  "documentation_url": "https://docs.github.com/rest/overview/resources-in-the-rest-api#rate-limiting"
}
```

**Step Action**: Wait 5 seconds, retry once (per clarification Q1). If second attempt also returns 429:
```
Error: GitHub API rate limit exceeded: wait and try again later
```

---

#### 503 Service Unavailable

**Cause**: GitHub API temporarily unavailable

**Response Body**:
```json
{
  "message": "Service Unavailable",
  "documentation_url": "https://docs.github.com/rest"
}
```

**Step Action**: Wait 5 seconds, retry once (per clarification Q1). If second attempt also returns 503:
```
Error: GitHub API temporarily unavailable: try again in a few moments
```

---

## Rate Limiting

**Primary Rate Limit**: 5,000 requests per hour per installation

**Secondary Rate Limit**: May apply for rapid requests (not documented threshold)

**Headers in Response**:
- `X-RateLimit-Limit`: Total rate limit
- `X-RateLimit-Remaining`: Requests remaining
- `X-RateLimit-Reset`: Unix timestamp when limit resets

**Handling**: This step makes 1-2 API calls per execution (max 2 with retry), so rate limiting is unlikely in normal usage.

---

## Security Considerations

### JWT Expiration

- **Maximum**: 10 minutes
- **Recommended**: Generate immediately before use
- **Our Implementation**: Generate with 10-minute expiration, use immediately

### Token Lifetime

- **Fixed**: 1 hour from generation
- **No Refresh**: Tokens cannot be refreshed, must generate new token after expiration
- **Scope**: Cannot exceed app's configured permissions

### HTTPS Required

- All API calls MUST use HTTPS
- Self-signed certificates not supported
- TLS 1.2+ required

---

## Error Handling Strategy

1. **JWT Generation Failure**: Exit 1 (validation error)
2. **Network Error**: Exit 2 with "Failed to reach GitHub API: check network connectivity"
3. **HTTP 401/404**: Exit 2 with specific error message
4. **HTTP 403/422**: Exit 2 with error from API response
5. **HTTP 429/503**: Wait 5s, retry once, then exit 2 if still failing
6. **Other HTTP Errors**: Exit 2 with generic error

**Retry Logic** (per clarification Q1):
- Applies to: HTTP 503 (Service Unavailable) and HTTP 429 (Rate Limit)
- Wait time: 5 seconds
- Max attempts: 2 (initial + 1 retry)
- Implementation: Sequential, not exponential backoff

---

## Testing Checklist

- [ ] Valid credentials → HTTP 201, token extracted
- [ ] Invalid App ID → HTTP 401, error displayed
- [ ] Invalid Installation ID → HTTP 404, error displayed
- [ ] Custom permissions (valid) → HTTP 201, token has requested permissions
- [ ] Custom permissions (invalid) → HTTP 403/422, error displayed
- [ ] Expired JWT → HTTP 401, error displayed
- [ ] Network error → Error message displayed
- [ ] API unavailable (503) → Retry after 5s, then fail with clear message
- [ ] Rate limit (429) → Retry after 5s, then fail with clear message

---

## References

- [GitHub REST API: Create installation access token](https://docs.github.com/en/rest/apps/apps#create-an-installation-access-token-for-an-app)
- [GitHub Apps: Authenticating](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app)
- [GitHub REST API: Rate limiting](https://docs.github.com/en/rest/overview/resources-in-the-rest-api#rate-limiting)
