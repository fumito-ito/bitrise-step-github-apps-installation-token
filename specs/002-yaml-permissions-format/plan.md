# Implementation Plan: YAML Permissions Format

**Branch**: `002-yaml-permissions-format` | **Date**: 2025-10-29 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-yaml-permissions-format/spec.md`

## Summary

Add support for YAML hash format for the `permissions` input parameter in the GitHub Apps Installation Token step. This enhancement improves developer experience by allowing users to specify permissions using native YAML syntax (key: value pairs) instead of JSON strings, making workflow configurations more readable and less error-prone. Based on research findings, Bitrise automatically serializes YAML hashes to JSON strings, so no format detection or conversion logic is needed in step.sh.

**Technical Approach**: Update step.yml to document YAML hash format and set `is_expand: false`, enhance error messages in step.sh to reference YAML hash format, update documentation with YAML examples, and add test workflows.

## Technical Context

**Language/Version**: Bash 4.x+ (POSIX-compatible shell script)
**Primary Dependencies**: jq (JSON validation - already required), envman (Bitrise environment management), openssl, curl, base64
**Storage**: N/A (stateless operation, no persistent storage)
**Testing**: Bitrise CLI (`bitrise run test`), shell script validation
**Target Platform**: Linux/macOS (Bitrise build environments)
**Project Type**: Bitrise Step (single shell script with YAML configuration)
**Performance Goals**: No performance impact (Bitrise handles serialization)
**Constraints**: Must leverage Bitrise's automatic YAML-to-JSON serialization, no new dependencies
**Scale/Scope**: Modification to existing step - affects 1 input parameter configuration, 1 error message, documentation updates, test workflows

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Shell-First Development (Principle I)**:
- [x] Implementation uses shell scripts (step.sh) as primary implementation language
- [x] External dependencies are minimal and justified (jq already required, no new dependencies)
- [x] No complex language-specific tooling required (pure bash + existing tools)

**Bitrise Step Standards Compliance (Principle II)**:
- [x] step.yml defines all inputs/outputs according to Bitrise spec (permissions input will be updated with better documentation)
- [x] Inputs accessed via environment variables (existing pattern maintained)
- [x] Outputs use envman for export (no changes to output mechanism)
- [x] Metadata (title, summary, description) is complete and accurate (will be updated to document YAML hash format)

**Secure Credential Handling (Principle III - NON-NEGOTIABLE)**:
- [x] Private keys/tokens passed via secure environment variables (no changes to credential handling)
- [x] No sensitive data logged to stdout/stderr (existing protection maintained)
- [x] Temporary files with sensitive data have 0600 permissions (no changes to temp file handling)
- [x] Cleanup of sensitive data on all exit paths (existing trap handlers unchanged)
- [x] All GitHub API calls use HTTPS (no changes to API integration)

**Clear Input/Output Contract (Principle IV)**:
- [x] All required inputs validated at start (existing validation maintained, error messages enhanced)
- [x] Validation failures exit with non-zero status (existing exit code 1 for validation errors)
- [x] Error messages are actionable (error messages will be enhanced to reference YAML hash format)
- [x] Success confirmation provided (existing success logging unchanged)

**Error Handling & Exit Codes (Principle V)**:
- [x] Exit code 0 for success, non-zero for failure (existing codes maintained: 0=success, 1=validation, 2=API, 3=envman)
- [x] set -e used for fail-fast behavior (existing pattern maintained)
- [x] Network/API/validation errors caught and reported (existing error handling maintained)
- [x] Cleanup actions run on failure (existing trap handlers unchanged)

**Constitution Compliance**: ✅ ALL CHECKS PASSED - No violations, no justification needed

## Project Structure

### Documentation (this feature)

```text
specs/002-yaml-permissions-format/
├── spec.md              # Feature specification (already created)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (to be generated)
├── data-model.md        # Phase 1 output (to be generated)
├── quickstart.md        # Phase 1 output (to be generated)
├── contracts/           # Phase 1 output (to be generated)
│   └── step-io-contract.md
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created yet)
```

### Source Code (repository root)

**Bitrise Step Structure** (flat layout at repository root):

```text
step.sh                  # Main implementation (MINOR CHANGES: enhanced error message)
step.yml                 # Step definition (MODIFIED: permissions input documentation and is_expand setting)
bitrise.yml              # Test workflows (MODIFIED: add YAML hash format tests)
README.md                # Documentation (MODIFIED: update examples to show YAML hash)

# Existing structure unchanged:
.bitrise.secrets.yml.example  # Example secrets file
.specify/                # Specification framework
specs/                   # Feature specifications
  001-github-apps-token/ # Original feature (existing)
  002-yaml-permissions-format/  # This feature (new)
```

**Structure Decision**: Bitrise steps use a flat structure with step.sh and step.yml at the repository root. This feature modifies existing files rather than adding new source files, maintaining the established Bitrise step architecture.

## Complexity Tracking

> **Not applicable** - No Constitution Check violations

All changes comply with the constitution. Minimal changes required: step.yml configuration update (`is_expand: false` + documentation), optional error message enhancement in step.sh, documentation updates, and test workflows.

---

## Phase 0: Research

**Objective**: Resolve technical unknowns about Bitrise YAML hash handling.

### Research Questions

1. **How does Bitrise serialize YAML hash inputs to environment variables?**
   - Investigate Bitrise documentation and step.yml specification
   - Determine format of environment variable (JSON string, key-value pairs, other)

2. **Is format detection needed in step.sh?**
   - Research whether step.sh can distinguish YAML hash from other formats
   - Determine if Bitrise provides metadata about original input format

3. **What validation is required for YAML hash format?**
   - Document validation approach (syntax, structure, edge cases)
   - Determine how to provide clear error messages

**Output**: `research.md` documenting findings and technical decisions

---

## Phase 1: Design

**Objective**: Create detailed design artifacts for implementation.

### 1. Data Model (`data-model.md`)

Document the permissions data structure:
- **YAML Hash Format**: `{ permission_name: access_level, ... }`
- **Bitrise Serialization**: How YAML hash is transformed to environment variable
- **GitHub API Format**: `{"permissions": {permission_name: access_level, ...}}`
- Transformation flow: YAML hash → (Bitrise serialization) → environment variable → GitHub API format
- Validation rules

### 2. Contracts (`contracts/step-io-contract.md`)

Define input/output specifications:
- **Updated permissions input**: Documentation and examples showing YAML hash format
- **Input validation**: How permissions are validated (JSON structure check)
- **Error messages**: Enhanced messages referencing YAML hash format
- **Example configurations**: YAML hash with various permission combinations

### 3. Migration Guide (`quickstart.md`)

Create user-facing guide:
- **YAML hash format examples**: Single permission, multiple permissions, write permissions
- **Edge cases**: Empty hash, inline vs multi-line YAML, quoted vs unquoted values
- **Troubleshooting**: Common issues (indentation, syntax errors)

### 4. Agent Context Update

Run `.specify/scripts/bash/update-agent-context.sh claude` to update CLAUDE.md with:
- YAML hash format support added to permissions parameter
- Bitrise serialization behavior
- No new dependencies or technologies

**Output**: `data-model.md`, `contracts/step-io-contract.md`, `quickstart.md`, updated `CLAUDE.md`

---

## Phase 2: Task Breakdown

**Not executed by `/speckit.plan`** - Run `/speckit.tasks` separately to generate `tasks.md`

Expected task categories:
1. **Setup**: Review existing step.yml and step.sh
2. **Configuration**: Update step.yml (is_expand, documentation)
3. **Enhancement**: Update step.sh error messages (optional)
4. **Testing**: Add test workflows for YAML hash format
5. **Documentation**: Update README.md with YAML examples
6. **Validation**: Test all scenarios (single permission, multiple, empty, invalid)

---

## Post-Design Constitution Re-Check

After completing Phase 1 design:

**Shell-First Development**: ✅ Maintained - No new dependencies, existing jq validation used
**Bitrise Standards**: ✅ Maintained - step.yml updated per Bitrise spec, no breaking changes
**Security**: ✅ Maintained - No changes to credential handling or API integration
**Clear Contract**: ✅ Enhanced - Error messages reference YAML hash format for better UX
**Error Handling**: ✅ Maintained - Existing exit codes and error handling preserved

**Final Compliance**: ✅ ALL CHECKS PASSED

---

## Notes

- This is a **documentation and configuration enhancement**, not a code rewrite
- Key insight from research needed: How does Bitrise serialize YAML hashes?
- No new external dependencies required (jq already handles JSON validation)
- Minimal code changes expected based on Bitrise serialization behavior
- Primary work is in step.yml documentation, examples, and test workflows
