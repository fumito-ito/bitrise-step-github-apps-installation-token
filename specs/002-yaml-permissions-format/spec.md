# Feature Specification: YAML Permissions Format

**Feature Branch**: `002-yaml-permissions-format`
**Created**: 2025-10-29
**Status**: Draft (Revised)
**Input**: User description: "need not to support json string format for backward compatibility. just support yaml hash format only."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - YAML Hash Format for Permissions (Priority: P1)

As a Bitrise workflow developer, I need to specify GitHub App permissions using native YAML hash syntax, so that my workflow configuration is more readable and consistent with YAML conventions.

**Why this priority**: This is the primary feature that improves developer experience. It eliminates the need to use JSON strings in YAML, making configurations more readable and less error-prone. This is the core value proposition of the feature.

**Independent Test**: Can be fully tested by configuring the step with YAML hash permissions (e.g., `contents: read, metadata: read`) and verifying the generated installation token has exactly those permissions via GitHub API query.

**Acceptance Scenarios**:

1. **Given** a workflow with permissions specified as YAML hash `contents: read, metadata: read`, **When** the step executes, **Then** the installation token is created with read access to contents and metadata
2. **Given** permissions specified as YAML hash with multiple permissions, **When** the step runs, **Then** the token has exactly the specified permissions (verifiable via GitHub API)
3. **Given** permissions specified as YAML hash with write access, **When** the step runs, **Then** the token has write permissions for the specified resources
4. **Given** no permissions specified (omitted or empty), **When** the step runs, **Then** the token has all permissions configured for the app installation

---

### Edge Cases

- What happens when permissions is an empty YAML hash `{}`?
- What happens when permissions contains invalid permission names that GitHub API rejects?
- How does the step handle YAML hash with null or empty string values?
- How are YAML formatting variations handled (inline vs. multi-line, with/without quotes)?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Step MUST accept permissions input as a YAML hash with permission names as keys and access levels (read/write) as values
- **FR-002**: Step MUST validate that permissions input (serialized to JSON by Bitrise) has valid JSON structure
- **FR-003**: Step MUST wrap JSON permissions object in `{"permissions": ...}` format for GitHub API compatibility
- **FR-004**: Step MUST handle empty or omitted permissions by defaulting to all app-configured permissions
- **FR-005**: Step MUST provide clear error messages when permissions JSON validation fails, referencing the YAML hash format users should provide
- **FR-006**: Documentation (README.md, step.yml descriptions) MUST show YAML hash format with clear examples
- **FR-007**: Test workflows (bitrise.yml) MUST include tests for YAML hash format with various permission combinations

### Key Entities

- **Permissions Map (YAML Hash)**: A YAML hash where keys are GitHub permission names (strings like "contents", "issues", "pull_requests") and values are access levels (strings: "read" or "write"). Bitrise automatically serializes this to a JSON string before passing to step.sh.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can configure permissions using YAML hash syntax by following README examples in under 2 minutes
- **SC-002**: Error messages for invalid permissions clearly indicate the YAML hash format expected and what the problem is
- **SC-003**: Documentation shows YAML hash format in all primary examples with multiple use cases covered

## Scope *(mandatory)*

### In Scope

- Adding support for YAML hash input type for permissions parameter
- Leveraging Bitrise's automatic YAML-to-JSON serialization (no format detection needed)
- Validating JSON structure using existing jq validation
- Wrapping JSON for GitHub API calls
- Updating all documentation to show YAML hash format
- Updating test workflows to cover YAML hash format
- Clear error messages for validation failures

### Out of Scope

- Adding new permission validation beyond JSON structure checking (GitHub API handles permission validity)
- Changing any other input parameters (app_id, installation_id, private_pem)
- Supporting nested YAML structures or complex permission configurations
- Format detection logic (Bitrise handles serialization automatically)

## Dependencies & Assumptions *(mandatory if applicable)*

### Dependencies

- Bitrise platform serializes YAML hash inputs to JSON strings automatically before passing to step.sh
- jq tool for JSON validation (already required by existing step implementation)

### Assumptions

- **ASM-001**: Bitrise automatically serializes YAML hash inputs to JSON strings before step.sh execution (verified in research phase)
- **ASM-002**: YAML hash values will always be simple strings ("read" or "write"), not nested structures
- **ASM-003**: Users understand basic YAML syntax for hashes (key: value pairs with indentation)
- **ASM-004**: GitHub API continues to accept JSON permission format as documented in their API specifications

## Non-Functional Requirements *(optional)*

### Usability

- **NFR-001**: YAML hash format must be visually clearer and more readable than JSON string format in workflow files
- **NFR-002**: Error messages must guide users to correct format issues with actionable suggestions

### Maintainability

- **NFR-003**: Implementation leverages Bitrise serialization to avoid complex format detection logic
- **NFR-004**: Code maintains single JSON processing path (no dual format handling)

## Open Questions / Clarifications

None. All aspects of this feature have been clarified based on research findings that Bitrise automatically serializes YAML hashes to JSON strings.
