<!--
Sync Impact Report:
- Version change: [initial] → 1.0.0
- Added principles:
  - I. Shell-First Development
  - II. Bitrise Step Standards Compliance
  - III. Secure Credential Handling (NON-NEGOTIABLE)
  - IV. Clear Input/Output Contract
  - V. Error Handling & Exit Codes
- Added sections:
  - Security Requirements
  - Development Workflow
- Templates requiring updates:
  - ✅ constitution.md (this file)
  - ⚠ .specify/templates/spec-template.md (needs review for step-specific requirements)
  - ⚠ .specify/templates/plan-template.md (needs review for step-specific constitution checks)
  - ⚠ .specify/templates/tasks-template.md (needs review for step-specific task categories)
- Follow-up TODOs:
  - Review templates to ensure they align with Bitrise step development patterns
-->

# Bitrise Step GitHub Apps Installation Token Constitution

## Core Principles

### I. Shell-First Development

All functionality MUST be implemented in shell scripts (primarily step.sh). Shell scripts provide:
- Direct compatibility with Bitrise CLI execution environment
- Transparent debugging and testing via standard shell tools
- Minimal dependencies beyond common Unix utilities
- Clear, auditable execution paths

**Rationale**: Bitrise steps execute in shell environments. Shell-first development ensures compatibility, simplicity, and aligns with Bitrise's execution model.

### II. Bitrise Step Standards Compliance

All development MUST follow Bitrise step standards:
- step.yml defines all inputs, outputs, and metadata according to Bitrise spec
- Inputs are accessed via environment variables prefixed with step name
- Outputs are exported using envman tool
- Step metadata (title, summary, description, website, support_url) MUST be accurate and complete
- Type tags correctly categorize the step for discoverability

**Rationale**: Compliance ensures the step integrates correctly with Bitrise workflows and provides a consistent user experience.

### III. Secure Credential Handling (NON-NEGOTIABLE)

Security requirements are MANDATORY and NON-NEGOTIABLE:
- Private keys, tokens, and credentials MUST be passed via secure environment variables
- Sensitive data MUST NOT be logged or printed to stdout/stderr
- Private key data MUST be handled in memory when possible, or written to temporary files with restrictive permissions (0600)
- Temporary files containing sensitive data MUST be cleaned up on exit (success or failure)
- All API calls to GitHub MUST use HTTPS
- JWT tokens MUST have appropriate expiration times

**Rationale**: This step handles GitHub App private keys and generates installation tokens. Security is paramount to protect user credentials and prevent unauthorized access.

### IV. Clear Input/Output Contract

Inputs and outputs MUST follow strict contracts:
- All required inputs MUST be validated at the start of execution
- Validation failures MUST exit with non-zero status and clear error messages
- Outputs MUST be exported via envman with documented environment variable names
- Success paths MUST provide confirmation of token generation
- Error messages MUST be actionable and indicate what the user needs to fix

**Rationale**: Clear contracts prevent silent failures and make troubleshooting straightforward for users.

### V. Error Handling & Exit Codes

Error handling MUST be comprehensive and predictable:
- Exit code 0 indicates successful token generation
- Non-zero exit codes indicate failure (Bitrise registers step as failed)
- set -e MUST be used to fail fast on command errors
- set -x MAY be used for debugging but MUST NOT expose sensitive data
- Network errors, API errors, and validation errors MUST be caught and reported clearly
- Cleanup actions (removing temp files) MUST run even on failure

**Rationale**: Bitrise workflows depend on exit codes to determine step success/failure. Proper error handling prevents silent failures and workflow corruption.

## Security Requirements

**Secret Management**:
- GitHub App private key MUST be provided via secret environment variable
- App ID and Installation ID MAY be non-secret but SHOULD be documented as sensitive
- Generated installation tokens MUST be treated as secrets in output

**Dependency Management**:
- External dependencies MUST be documented in step.yml deps section
- Required tools (e.g., openssl, curl, jq) MUST be validated before use
- Version requirements MUST be specified if tool behavior varies

**Audit & Logging**:
- Authentication events (JWT creation, token requests) MUST be logged (without sensitive data)
- API responses MUST be validated for expected structure
- Token expiration times MUST be logged for user awareness

## Development Workflow

**Testing Requirements**:
- Step MUST be testable via `bitrise run test` locally
- Test configuration in bitrise.yml MUST include example inputs (non-sensitive placeholders)
- .bitrise.secrets.yml (git-ignored) used for local secret testing
- Integration testing with real GitHub Apps SHOULD be documented

**Version Management**:
- Step versions follow semantic versioning (MAJOR.MINOR.PATCH)
- Breaking changes to inputs/outputs require MAJOR version bump
- New features or inputs require MINOR version bump
- Bug fixes and improvements require PATCH version bump

**Code Review Standards**:
- All changes MUST maintain backwards compatibility unless MAJOR version bump
- Shell script changes MUST be tested with bitrise CLI
- step.yml changes MUST be validated with `bitrise run audit-this-step`

**Documentation Requirements**:
- README.md MUST explain how to configure GitHub App credentials
- step.yml descriptions MUST be clear and include examples
- Error messages MUST be documented with resolution steps

## Governance

This constitution defines the non-negotiable principles for developing the Bitrise Step GitHub Apps Installation Token project. All development decisions, code reviews, and feature implementations MUST comply with these principles.

**Amendment Process**:
- Constitution changes require explicit justification and version bump
- Security principles (III) cannot be weakened or removed
- Amendments MUST be documented in Sync Impact Report
- Dependent templates MUST be reviewed and updated after amendments

**Compliance Review**:
- All pull requests MUST verify compliance with Core Principles (I-V)
- Security requirements MUST be verified for all changes handling credentials
- Shell script changes MUST NOT introduce dependencies without deps declaration
- Exit code handling MUST be validated in all error paths

**Complexity Justification**:
- Additional dependencies MUST be justified against principle of minimal dependencies (I)
- Any non-shell implementation MUST justify why shell-first is insufficient
- Template modifications MUST align with Bitrise step development patterns

**Version**: 1.0.0 | **Ratified**: 2025-10-27 | **Last Amended**: 2025-10-27
