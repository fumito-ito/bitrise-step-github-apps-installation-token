# Feature Specification: YAML Permissions Format

**Feature Branch**: `002-yaml-permissions-format`
**Created**: 2025-10-29
**Status**: Draft
**Input**: User description: "Change the permissions specification method to use YAML hash format. Specifically, make the following changes:

Current specification method:
- permissions: '{\"contents\":\"read\",\"metadata\":\"read\"}'

New specification method:
- permissions:
    contents: read
    metadata: read"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - YAML Hash Format for Permissions (Priority: P1)

As a Bitrise workflow developer, I need to specify GitHub App permissions using native YAML hash syntax instead of JSON strings, so that my workflow configuration is more readable and consistent with YAML conventions.

**Why this priority**: This is the primary feature that improves developer experience. It eliminates the need to escape JSON strings in YAML, making configurations more readable and less error-prone. This is the core value proposition of the feature.

**Independent Test**: Can be fully tested by configuring the step with YAML hash permissions (e.g., `contents: read, metadata: read`) and verifying the generated installation token has exactly those permissions via GitHub API query.

**Acceptance Scenarios**:

1. **Given** a workflow with permissions specified as YAML hash `contents: read, metadata: read`, **When** the step executes, **Then** the installation token is created with read access to contents and metadata
2. **Given** permissions specified as YAML hash with multiple permissions, **When** the step runs, **Then** the token has exactly the specified permissions (verifiable via GitHub API)
3. **Given** permissions specified as YAML hash with write access, **When** the step runs, **Then** the token has write permissions for the specified resources
4. **Given** no permissions specified (omitted or empty), **When** the step runs, **Then** the token has all permissions configured for the app installation

---

### User Story 2 - Backward Compatibility with JSON String Format (Priority: P2)

As an existing user of the step, I need my current JSON string permission configurations to continue working without modifications, so that I can upgrade the step version without breaking my workflows and migrate to the new format at my own pace.

**Why this priority**: While less critical than the new feature, backward compatibility is essential to avoid disrupting existing users. This allows gradual adoption and prevents breaking changes that would require immediate updates to all workflows.

**Independent Test**: Can be tested by running workflows with the old JSON string format `'{"contents":"read","metadata":"read"}'` and verifying they still generate tokens with correct permissions.

**Acceptance Scenarios**:

1. **Given** permissions specified as JSON string `'{"contents":"read"}'`, **When** the step executes, **Then** the token is created successfully with read access to contents
2. **Given** permissions specified as JSON string with multiple permissions, **When** the step runs, **Then** the token has exactly the specified permissions (same as before the change)
3. **Given** workflows using both old JSON and new YAML formats in different builds, **When** both execute, **Then** both successfully generate tokens with their respective permissions

---

### Edge Cases

- What happens when permissions is an empty YAML hash `{}`?
- What happens when permissions contains invalid permission names that GitHub API rejects?
- How does the step handle YAML hash with null or empty string values?
- What if permissions is specified as a plain string that's neither valid JSON nor valid YAML hash?
- How are YAML formatting variations handled (inline vs. multi-line, with/without quotes)?
- What happens when user provides malformed JSON string (current format)?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Step MUST accept permissions input as a YAML hash/map data type with permission names as keys and access levels (read/write) as values
- **FR-002**: Step MUST continue to accept permissions input as a JSON string for backward compatibility with existing workflows
- **FR-003**: Step MUST automatically detect whether the permissions input is a YAML hash or JSON string without requiring user configuration
- **FR-004**: Step MUST convert YAML hash permissions to JSON object format required by GitHub API (`{"permissions": {...}}`)
- **FR-005**: Step MUST validate that YAML hash permissions have valid structure (non-empty keys, string values of "read" or "write")
- **FR-006**: Step MUST validate that JSON string permissions (legacy format) are valid JSON before attempting to parse
- **FR-007**: Step MUST provide clear error messages distinguishing between YAML hash validation failures and JSON string validation failures
- **FR-008**: Step MUST handle empty or omitted permissions (both YAML and JSON) by defaulting to all app-configured permissions
- **FR-009**: Documentation (README.md, step.yml descriptions) MUST show YAML hash format as the primary and recommended approach
- **FR-010**: Documentation MUST include examples of both YAML hash and JSON string formats, noting JSON string as deprecated but supported
- **FR-011**: Test workflows (bitrise.yml) MUST include tests for both YAML hash and JSON string formats to ensure both work

### Key Entities

- **Permissions Map (YAML Hash)**: A YAML hash/map where keys are GitHub permission names (strings like "contents", "issues", "pull_requests") and values are access levels (strings: "read" or "write")
- **Permissions JSON (Legacy)**: A JSON-formatted string representing the same permission structure, enclosed in quotes

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can configure permissions using YAML hash syntax by following README examples in under 2 minutes
- **SC-002**: Existing workflows using JSON string permissions continue to function without any code changes after step upgrade
- **SC-003**: Error messages for invalid permissions clearly indicate which format (YAML hash or JSON string) has validation issues and what the problem is
- **SC-004**: Documentation shows YAML hash format in primary examples, with JSON string format noted as legacy/deprecated

## Scope *(mandatory)*

### In Scope

- Adding support for YAML hash/map input type for permissions parameter
- Maintaining full backward compatibility with JSON string format
- Auto-detecting input format (YAML hash vs JSON string)
- Converting YAML hash to JSON for GitHub API calls
- Updating all documentation to show YAML hash as primary format
- Updating test workflows to cover both formats
- Clear error messages for both format types

### Out of Scope

- Removing or deprecating JSON string format support (it remains supported indefinitely)
- Adding new permission validation beyond format checking (GitHub API handles permission validity)
- Changing any other input parameters (app_id, installation_id, private_pem)
- Supporting nested YAML structures or complex permission configurations
- Auto-migration of existing workflows from JSON to YAML format

## Dependencies & Assumptions *(mandatory if applicable)*

### Dependencies

- Bitrise step.yml format must support hash/map data types for input parameters (assumed to be standard YAML functionality)
- Bash/shell scripting must be able to detect and differentiate between string and hash/map data types from environment variables

### Assumptions

- **ASM-001**: Bitrise passes YAML hash inputs as environment variables in a format that can be detected and parsed by shell scripts (e.g., serialized as JSON or as separate key-value pairs)
- **ASM-002**: The step can introspect the permissions input to determine its type (string vs hash/map) before processing
- **ASM-003**: YAML hash values will always be simple strings ("read" or "write"), not nested structures
- **ASM-004**: Users understand basic YAML syntax for hashes (key: value pairs with indentation)
- **ASM-005**: Existing JSON string format users will see deprecation notice but continue using it until they choose to migrate
- **ASM-006**: GitHub API continues to accept JSON permission format as documented in their API specifications

## Non-Functional Requirements *(optional)*

### Usability

- **NFR-001**: YAML hash format must be visually clearer and more readable than JSON string format in workflow files
- **NFR-002**: Error messages must guide users to correct format issues in both YAML and JSON formats

### Maintainability

- **NFR-003**: Code must cleanly separate YAML hash processing logic from JSON string processing logic for future maintenance

## Open Questions / Clarifications

None. All aspects of this feature have reasonable defaults based on standard YAML conventions and GitHub API requirements.
