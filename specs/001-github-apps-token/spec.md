# Feature Specification: GitHub Apps Installation Token Generator

**Feature Branch**: `001-github-apps-token`
**Created**: 2025-10-28
**Status**: Draft
**Input**: User description: "This Bitrise step receives github_apps_private_pem, github_apps_installation_id, and permissions as arguments to generate a GitHub Apps Installation Token. The generated Installation Token is saved to an environment variable using envman add --key GITHUB_APPS_INSTALLATION_TOKEN --value {generated token}."

## Clarifications

### Session 2025-10-28

- Q: How should the step handle GitHub API rate limits or temporary unavailability? → A: Wait and retry once after 5 seconds, then fail if still unavailable
- Q: How should the step handle PEM keys with extra whitespace or formatting differences? → A: Auto-normalize whitespace (trim leading/trailing, normalize line breaks) and proceed if valid structure
- Q: How should the step handle different permission format variations? → A: Pass through to GitHub API without validation - let GitHub validate and return errors
- Q: Should the step verify that envman successfully exported the token? → A: Verify envman exit code - fail step if envman export fails

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Generate Installation Token with Basic Inputs (Priority: P1)

As a Bitrise workflow user, I need to generate a GitHub Apps Installation Token by providing my App ID, Installation ID, and private PEM key, so that subsequent workflow steps can authenticate to GitHub using the generated token.

**Why this priority**: This is the core functionality that delivers immediate value. Without this, the step cannot function. It represents the minimum viable product that enables GitHub API authentication in Bitrise workflows.

**Independent Test**: Can be fully tested by providing valid GitHub App credentials (App ID, Installation ID, private PEM) to the step and verifying that a valid installation token is exported to the GITHUB_APPS_INSTALLATION_TOKEN environment variable.

**Acceptance Scenarios**:

1. **Given** a valid GitHub App with ID and private PEM key, **When** I provide the App ID, Installation ID, and private PEM to the step, **Then** an installation token is generated and exported to GITHUB_APPS_INSTALLATION_TOKEN
2. **Given** valid credentials, **When** the step executes successfully, **Then** the workflow step exits with code 0 indicating success
3. **Given** valid credentials, **When** the step generates a token, **Then** the token has a 1-hour expiration time as defined by GitHub
4. **Given** the generated token, **When** I use it in subsequent workflow steps, **Then** I can successfully authenticate to GitHub APIs within the app's installation scope

---

### User Story 2 - Custom Permission Scopes (Priority: P2)

As a security-conscious workflow user, I want to restrict the installation token to only the permissions my workflow needs, so that I follow the principle of least privilege and minimize security risk.

**Why this priority**: While the basic token generation (P1) is essential, being able to limit permissions enhances security. This is valuable for production workflows but not blocking for initial functionality.

**Independent Test**: Can be tested independently by providing a permissions parameter (e.g., "contents:read,issues:write") and verifying that the generated token has only those permissions instead of all the app's configured permissions.

**Acceptance Scenarios**:

1. **Given** I specify custom permissions in the permissions parameter, **When** the step generates the token, **Then** the token has only the specified permissions
2. **Given** I omit the permissions parameter, **When** the step generates the token, **Then** the token inherits all permissions configured for the app's installation
3. **Given** I specify permissions not granted to the app, **When** the step attempts to generate the token, **Then** I receive a clear error message indicating which permissions are unavailable

---

### User Story 3 - Helpful Error Messages and Validation (Priority: P3)

As a workflow user, I need clear error messages when token generation fails, so that I can quickly diagnose and fix configuration issues without consulting external documentation.

**Why this priority**: This improves user experience and reduces debugging time, but the step can function without enhanced error messages. Basic error reporting from P1 is sufficient for MVP.

**Independent Test**: Can be tested by providing various invalid inputs (missing App ID, malformed PEM, wrong Installation ID) and verifying that each produces a specific, actionable error message.

**Acceptance Scenarios**:

1. **Given** I provide a missing or empty App ID, **When** the step validates inputs, **Then** I see an error message "App ID is required" and the step exits with non-zero code
2. **Given** I provide a malformed private PEM key, **When** the step validates the key, **Then** I see an error message "Invalid PEM format: ensure the key includes BEGIN/END markers" and the step exits with non-zero code
3. **Given** I provide an incorrect Installation ID, **When** the GitHub API returns an error, **Then** I see an error message "Installation ID not found: verify the installation exists and the App ID is correct"
4. **Given** network connectivity issues, **When** the step attempts to call GitHub API, **Then** I see an error message "Failed to reach GitHub API: check network connectivity"

---

### Edge Cases

- **Private PEM key with extra whitespace or formatting differences**: Step automatically normalizes whitespace (trims leading/trailing whitespace, normalizes line breaks) before validation. If the normalized key has valid structure (BEGIN/END markers), it proceeds; otherwise, validation fails with a clear error message.
- **GitHub API rate limits or temporary unavailability**: Step waits 5 seconds and retries once. If the second attempt fails, the step exits with a clear error message indicating rate limit or unavailability.
- What happens when the App ID or Installation ID contains non-numeric characters?
- **Permissions parameter with invalid names or different formats**: Step passes the permissions parameter through to GitHub API without format validation. GitHub API validates the format and returns clear error messages for invalid permissions. The step relays these errors to the user with context about which permissions were rejected.
- How does the step handle cleanup if it fails partway through (e.g., after creating temporary files)?
- **Environment variable propagation**: Step verifies envman's exit code after exporting the token. If envman export fails (non-zero exit code), the step fails with a clear error message. This ensures the token is available for subsequent workflow steps before reporting success.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Step MUST accept a GitHub App ID as input via environment variable
- **FR-002**: Step MUST accept a GitHub App Installation ID as input via environment variable
- **FR-003**: Step MUST accept a GitHub App private PEM key as input via secure environment variable
- **FR-004**: Step MUST accept an optional permissions parameter to restrict token scope
- **FR-005**: Step MUST validate all required inputs (App ID, Installation ID, private PEM) before attempting token generation
- **FR-006**: Step MUST generate a JWT (JSON Web Token) with RS256 signing, using the private PEM key, with appropriate claims (iat, exp, iss) and maximum 10-minute expiration
- **FR-007**: Step MUST make an authenticated API request to GitHub to exchange the JWT for an installation access token
- **FR-008**: Step MUST export the generated installation token to the environment variable GITHUB_APPS_INSTALLATION_TOKEN using envman and verify envman's exit code. If envman export fails, step MUST exit with non-zero code and clear error message
- **FR-009**: Step MUST NOT log or print sensitive data (private keys, JWTs, tokens) to stdout or stderr
- **FR-010**: Step MUST use secure file permissions (0600) for any temporary files containing sensitive data
- **FR-011**: Step MUST clean up temporary files containing sensitive data on both success and failure exit paths
- **FR-012**: Step MUST exit with code 0 on successful token generation and non-zero on any failure
- **FR-013**: Step MUST handle network errors gracefully and provide actionable error messages
- **FR-014**: Step MUST handle GitHub API errors (invalid credentials, missing installation, API rate limits) and provide clear error messages. For rate limits or temporary unavailability, step MUST wait 5 seconds and retry once before failing
- **FR-015**: Step MUST normalize whitespace in the PEM key (trim leading/trailing, normalize line breaks) and then validate the PEM key format (BEGIN/END markers, structure) before attempting to use it
- **FR-016**: When permissions parameter is provided, step MUST include it in the token generation request to GitHub API without performing format validation (GitHub API validates)
- **FR-017**: When permissions parameter is omitted, step MUST generate token with app's default configured permissions
- **FR-018**: When GitHub API rejects permissions due to invalid format or unavailable permissions, step MUST relay the API error message with context about which permissions were rejected

### Key Entities

- **GitHub App**: Represents the application registered on GitHub, identified by App ID, authenticated with private PEM key
- **Installation**: Represents the GitHub App installed on a specific account/organization, identified by Installation ID
- **JWT (JSON Web Token)**: Time-limited authentication token (max 10 minutes) used to authenticate as the GitHub App
- **Installation Access Token**: The generated token (1-hour expiration) that provides API access with specific permissions for the installation
- **Permissions**: Optional scope restrictions defining what the installation token can access (e.g., repository contents, issues, pull requests)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can generate a valid installation token in under 30 seconds with valid credentials
- **SC-002**: 95% of token generation attempts with valid credentials complete successfully
- **SC-003**: Error messages enable users to resolve common issues (missing credentials, invalid format, wrong IDs) without consulting external documentation
- **SC-004**: Generated tokens have the correct 1-hour expiration time as specified by GitHub's API
- **SC-005**: No sensitive data (private keys, tokens, JWTs) appears in Bitrise step logs
- **SC-006**: 100% of temporary files containing sensitive data are cleaned up after step completion (success or failure)
- **SC-007**: When custom permissions are specified, 100% of generated tokens have only the specified permissions (not the full app permissions)

## Assumptions

- Users have already created a GitHub App and have access to its App ID and private PEM key
- Users have installed the GitHub App on their account/organization and know the Installation ID
- Users are running the step in a Bitrise environment with envman available
- The Bitrise environment has network connectivity to GitHub's API (api.github.com)
- Standard Unix utilities for JWT generation (openssl, base64) are available in the Bitrise environment
- The GitHub App has been configured with appropriate permissions before installation
- Users understand that the generated token expires after 1 hour and may need to be regenerated for long-running workflows
