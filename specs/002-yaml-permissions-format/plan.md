# Implementation Plan: YAML Permissions Format

**Branch**: `002-yaml-permissions-format` | **Date**: 2025-10-29 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-yaml-permissions-format/spec.md`

## Summary

Add support for YAML hash/map format for the `permissions` input parameter in the GitHub Apps Installation Token step, while maintaining full backward compatibility with the existing JSON string format. This enhancement improves developer experience by allowing users to specify permissions using native YAML syntax (key: value pairs) instead of escaped JSON strings, making workflow configurations more readable and less error-prone.

**Technical Approach**: Modify step.yml to accept hash/map input type, update step.sh to auto-detect input format (YAML hash vs JSON string) and convert YAML hash to JSON for GitHub API compatibility, while preserving all existing functionality and security measures.

## Technical Context

**Language/Version**: Bash 4.x+ (POSIX-compatible shell script)
**Primary Dependencies**: jq (JSON parsing/generation), envman (Bitrise environment management), openssl, curl, base64
**Storage**: N/A (stateless operation, no persistent storage)
**Testing**: Bitrise CLI (`bitrise run test`), shell script validation
**Target Platform**: Linux/macOS (Bitrise build environments)
**Project Type**: Bitrise Step (single shell script with YAML configuration)
**Performance Goals**: Format detection and conversion add <10ms overhead (negligible impact)
**Constraints**: Must maintain backward compatibility, no breaking changes to existing workflows
**Scale/Scope**: Modification to existing step, affects 1 input parameter, 1 validation function, 1 conversion function, documentation updates

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Shell-First Development (Principle I)**:
- [x] Implementation uses shell scripts (step.sh) as primary implementation language
- [x] External dependencies are minimal and justified (jq already required, no new dependencies)
- [x] No complex language-specific tooling required (pure bash + existing tools)

**Bitrise Step Standards Compliance (Principle II)**:
- [x] step.yml defines all inputs/outputs according to Bitrise spec (permissions input updated to accept hash/map)
- [x] Inputs accessed via environment variables (existing pattern maintained)
- [x] Outputs use envman for export (no changes to output mechanism)
- [x] Metadata (title, summary, description) is complete and accurate (will be updated to reflect new format)

**Secure Credential Handling (Principle III - NON-NEGOTIABLE)**:
- [x] Private keys/tokens passed via secure environment variables (no changes to credential handling)
- [x] No sensitive data logged to stdout/stderr (existing protection maintained)
- [x] Temporary files with sensitive data have 0600 permissions (no changes to temp file handling)
- [x] Cleanup of sensitive data on all exit paths (existing trap handlers unchanged)
- [x] All GitHub API calls use HTTPS (no changes to API integration)

**Clear Input/Output Contract (Principle IV)**:
- [x] All required inputs validated at start (new validation added for YAML hash format)
- [x] Validation failures exit with non-zero status (existing exit code 1 for validation errors)
- [x] Error messages are actionable (new messages distinguish YAML hash vs JSON string errors)
- [x] Success confirmation provided (existing success logging unchanged)

**Error Handling & Exit Codes (Principle V)**:
- [x] Exit code 0 for success, non-zero for failure (existing codes maintained: 0=success, 1=validation, 2=API, 3=envman)
- [x] set -e used for fail-fast behavior (existing pattern maintained)
- [x] Network/API/validation errors caught and reported (new validation integrated into existing error handling)
- [x] Cleanup actions run on failure (existing trap handlers unchanged)

**Constitution Compliance**: ✅ ALL CHECKS PASSED - No violations, no justification needed

## Project Structure

### Documentation (this feature)

```text
specs/002-yaml-permissions-format/
├── spec.md              # Feature specification (already created)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (technical research findings)
├── data-model.md        # Phase 1 output (permissions data structure)
├── quickstart.md        # Phase 1 output (migration guide for users)
├── contracts/           # Phase 1 output (I/O specifications)
│   └── step-io-contract.md  # Updated input/output contract
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created yet)
```

### Source Code (repository root)

**Bitrise Step Structure** (flat layout at repository root):

```text
step.sh                  # Main implementation (MODIFIED: format detection and conversion)
step.yml                 # Step definition (MODIFIED: permissions input configuration)
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

All changes comply with the constitution. No additional complexity introduced beyond the minimal format detection and conversion logic required for the feature.

---

## Phase 0: Research

**Objective**: Resolve all technical unknowns about Bitrise YAML hash handling and format detection strategies.

**Status**: ✅ COMPLETED

### Research Questions

1. **How does Bitrise serialize YAML hash inputs to environment variables?**
   - ✅ Investigated Bitrise documentation and step.yml specification
   - ✅ Finding: Bitrise automatically serializes YAML hashes to JSON strings

2. **What is the optimal format detection strategy in bash?**
   - ✅ Research completed - format detection NOT needed
   - ✅ Finding: Both formats become identical JSON strings after Bitrise serialization

3. **How to convert YAML hash to JSON using existing tools (jq)?**
   - ✅ Research completed - conversion NOT needed
   - ✅ Finding: Bitrise handles conversion automatically, step.sh receives JSON

4. **What validation is needed for YAML hash format?**
   - ✅ Research completed - existing validation sufficient
   - ✅ Finding: `jq empty` validation already handles both formats

**Output**: ✅ [research.md](research.md) - All findings documented, 5 research areas resolved

---

## Phase 1: Design

**Objective**: Create detailed design artifacts for implementation.

**Status**: ✅ COMPLETED

### 1. Data Model (`data-model.md`)

✅ **COMPLETED** - [data-model.md](data-model.md)

Documented:
- ✅ YAML Hash Format and JSON String Format structures
- ✅ GitHub API Format with transformation flow
- ✅ Format equivalence (both become identical JSON strings)
- ✅ Validation rules for both formats (jq-based)
- ✅ Edge cases and common permission examples

### 2. Contracts (`contracts/step-io-contract.md`)

✅ **COMPLETED** - [contracts/step-io-contract.md](contracts/step-io-contract.md)

Defined:
- ✅ Updated permissions input specification (accepts both formats)
- ✅ Input validation contract with enhanced error messages
- ✅ Output contract (unchanged from original)
- ✅ Error contract with exit codes and messages
- ✅ Backward compatibility guarantees
- ✅ Example workflows for both formats

### 3. Migration Guide (`quickstart.md`)

✅ **COMPLETED** - [quickstart.md](quickstart.md)

Created:
- ✅ Quick comparison (before/after examples)
- ✅ Step-by-step migration guide
- ✅ Common migration scenarios with examples
- ✅ Backward compatibility assurance
- ✅ Troubleshooting guide for both formats
- ✅ Examples by use case (CI/CD, deployment, issues, read-only)

### 4. Agent Context Update

✅ **COMPLETED** - CLAUDE.md updated

Updated:
- ✅ Language: Bash 4.x+ (POSIX-compatible shell script)
- ✅ Framework: jq, envman, openssl, curl, base64
- ✅ Database: N/A (stateless operation)
- ✅ Project type: Bitrise Step

**Output**: ✅ All design artifacts completed - [data-model.md](data-model.md), [contracts/step-io-contract.md](contracts/step-io-contract.md), [quickstart.md](quickstart.md), CLAUDE.md updated

---

## Phase 2: Task Breakdown

**Not executed by `/speckit.plan`** - Run `/speckit.tasks` separately to generate `tasks.md`

Expected task categories:
1. **Setup**: Update step.yml to accept hash/map input type
2. **Core Logic**: Add format detection in step.sh
3. **Conversion**: Implement YAML hash to JSON conversion
4. **Validation**: Update validation for both formats
5. **Testing**: Add test workflows for YAML hash format
6. **Documentation**: Update README.md examples
7. **Polish**: Update error messages and deprecation notices

---

## Post-Design Constitution Re-Check

After completing Phase 1 design:

**Shell-First Development**: ✅ Maintained - Pure bash implementation, jq (already required)
**Bitrise Standards**: ✅ Maintained - step.yml updated per Bitrise spec
**Security**: ✅ Maintained - No changes to credential handling
**Clear Contract**: ✅ Enhanced - Both formats validated with clear error messages
**Error Handling**: ✅ Maintained - Existing exit codes and error handling preserved

**Final Compliance**: ✅ ALL CHECKS PASSED

---

## Notes

- This is a **backward-compatible enhancement**, not a breaking change
- Existing workflows using JSON string format continue to work without modification
- YAML hash format becomes the recommended approach in updated documentation
- JSON string format remains supported indefinitely (deprecated but maintained)
- No new dependencies introduced (jq already required for existing JSON parsing)
- Minimal performance impact (<10ms for format detection and conversion)
