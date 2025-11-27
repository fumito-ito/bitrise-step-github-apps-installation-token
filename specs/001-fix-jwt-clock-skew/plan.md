# Implementation Plan: Fix JWT Clock Skew Errors

**Branch**: `001-fix-jwt-clock-skew` | **Date**: 2025-11-19 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-fix-jwt-clock-skew/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Fix intermittent 401 errors caused by JWT exp claim clock skew when generating GitHub Apps installation tokens. The solution adjusts JWT expiration to 5 minutes (instead of 10) to provide a safety margin for clock differences up to ±5 minutes, validates system time availability, detects extreme clock errors (>1 hour), and provides diagnostic logging for troubleshooting. All timestamps will use UTC per RFC 7519 standard.

## Technical Context

**Language/Version**: Bash 4.x+ (POSIX-compatible shell script)
**Primary Dependencies**: openssl (RS256 JWT signing), curl (GitHub API calls), jq (JSON parsing), envman (Bitrise environment management - pre-installed), base64, date (UTC time retrieval)
**Storage**: N/A (stateless operation, temporary PEM files with 0600 permissions)
**Testing**: Bitrise CLI (`bitrise run test`), manual testing with varied system clocks
**Target Platform**: Bitrise CI/CD execution environment (Linux/macOS)
**Project Type**: Single (Bitrise step - shell script implementation)
**Performance Goals**: Token generation completes within 5 seconds under normal network conditions
**Constraints**: Must work in Bitrise's shell environment, no additional language runtimes, all GitHub API calls via HTTPS, JWT exp must never exceed 10 minutes from iat
**Scale/Scope**: Single shell script (step.sh), modification to JWT generation logic (~50-100 LOC change)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Shell-First Development (Principle I)**:
- [x] Implementation uses shell scripts (step.sh) as primary implementation language - This is a modification to existing step.sh
- [x] External dependencies are minimal and justified - Only uses existing dependencies (openssl, curl, jq, date) + date for UTC time
- [x] No complex language-specific tooling required - Pure bash implementation

**Bitrise Step Standards Compliance (Principle II)**:
- [x] step.yml defines all inputs/outputs according to Bitrise spec - No changes needed to step.yml for this fix
- [x] Inputs accessed via environment variables - Existing implementation complies
- [x] Outputs use envman for export - Existing implementation complies
- [x] Metadata (title, summary, description) is complete and accurate - No changes needed

**Secure Credential Handling (Principle III - NON-NEGOTIABLE)**:
- [x] Private keys/tokens passed via secure environment variables - Existing implementation complies
- [x] No sensitive data logged to stdout/stderr - Will verify timing logs don't expose JWT payload
- [x] Temporary files with sensitive data have 0600 permissions - Existing implementation complies
- [x] Cleanup of sensitive data on all exit paths - Existing trap handler covers this
- [x] All GitHub API calls use HTTPS - Existing implementation complies

**Clear Input/Output Contract (Principle IV)**:
- [x] All required inputs validated at start - Existing implementation validates; will add UTC time validation
- [x] Validation failures exit with non-zero status - Existing implementation complies
- [x] Error messages are actionable - Will add clear messages for clock skew and time retrieval errors
- [x] Success confirmation provided - Existing implementation provides confirmation

**Error Handling & Exit Codes (Principle V)**:
- [x] Exit code 0 for success, non-zero for failure - Existing implementation complies
- [x] set -e used for fail-fast behavior - Existing step.sh uses `set -e`
- [x] Network/API/validation errors caught and reported - Existing implementation has error handling
- [x] Cleanup actions run on failure - Existing trap handler runs on EXIT ERR INT TERM

**Gate Status**: ✅ PASS - All constitution principles satisfied. This is a targeted fix to existing compliant code.

## Project Structure

### Documentation (this feature)

```text
specs/001-fix-jwt-clock-skew/
├── spec.md              # Feature specification (completed)
├── plan.md              # This file (in progress)
├── research.md          # Phase 0 output (to be generated)
├── data-model.md        # Phase 1 output (to be generated)
├── quickstart.md        # Phase 1 output (to be generated)
├── contracts/           # Phase 1 output (to be generated)
│   └── jwt-payload.json # JWT structure documentation
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# Bitrise Step Structure (Single shell script project)
.
├── step.sh              # Main implementation - JWT generation logic to be modified
├── step.yml             # Bitrise step definition - no changes needed
├── bitrise.yml          # Local testing configuration
├── CLAUDE.md            # Project context - will be updated with clock skew handling
└── README.md            # User documentation - may need update for troubleshooting

# Testing
.bitrise.secrets.yml     # Local secrets for testing (git-ignored)
```

**Structure Decision**: This is a Bitrise step following the standard single shell script pattern. All modifications will be to `step.sh`, specifically to the JWT generation function. The existing structure is already compliant with Bitrise standards and our constitution principles. No new files or directories are needed - this is a targeted bug fix within the existing codebase.

## Complexity Tracking

N/A - No constitution violations. This fix uses existing dependencies and follows established patterns.

---

## Phase 0: Research (Complete)

All technical unknowns have been resolved through research:

- **JWT Clock Skew Mitigation**: Conservative 5-minute expiration (vs. 10-minute max) provides safety buffer
- **UTC Time Retrieval**: `date -u +%s` provides cross-platform UTC epoch seconds
- **Extreme Clock Detection**: Validate timestamps against 2020-2100 epoch range
- **Diagnostic Logging**: Log iat, exp, current_time (epochs only, no JWT tokens)
- **Error Handling**: Explicit validation with descriptive messages

📄 **Artifact**: [research.md](research.md)

---

## Phase 1: Design & Contracts (Complete)

### Data Model

**Key entities identified**:
- UTC Timestamp: Integer epoch seconds, validated range 2020-2100
- JWT Payload: `{iat, exp, iss}` with exp = iat + 300 (changed from iat + 600)
- Timing Diagnostic Data: Logged epoch values for troubleshooting

📄 **Artifact**: [data-model.md](data-model.md)

### Contracts

**JWT Payload Schema** (JSON Schema with validation rules):
- `iat`: UTC epoch seconds, current time at generation
- `exp`: UTC epoch seconds, exactly iat + 300
- `iss`: GitHub App ID (string)
- Includes examples, counterexamples, and constraints

📄 **Artifact**: [contracts/jwt-payload.json](contracts/jwt-payload.json)

### Testing Guide

**Quickstart scenarios**:
1. Normal operation
2. Simulated clock skew (future/past)
3. Extreme clock error detection
4. UTC vs local time verification
5. Time retrieval failure
6. Diagnostic logging on 401 error
7. Performance benchmark
8. Regression tests

📄 **Artifact**: [quickstart.md](quickstart.md)

### Agent Context Update

Updated `CLAUDE.md` with:
- Added `date (UTC time retrieval)` to Active Technologies
- Added feature context for 001-fix-jwt-clock-skew
- Documented JWT exp duration change (10→5 minutes)
- Added clock validation requirements

---

## Constitution Re-Check (Post-Design)

**Status**: ✅ PASS - No changes from initial check

All design decisions comply with project constitution:
- Pure shell implementation (no new dependencies)
- Bitrise standards maintained (no step.yml changes)
- Security preserved (no sensitive data in logs)
- Clear error messages and exit codes
- Existing trap handlers and validation patterns extended

---

## Next Steps

### Immediate: Task Generation

Run `/speckit.tasks` to generate the implementation task breakdown from this plan.

**Expected task categories**:
- Time validation functions
- JWT generation modification
- Error handling enhancements
- Diagnostic logging additions
- Testing and verification

### Implementation Approach

**Recommended order**:
1. Add UTC timestamp validation function
2. Modify JWT exp calculation (600→300)
3. Add extreme clock detection
4. Enhance 401 error logging
5. Test all scenarios per quickstart.md

**Estimated effort**: 2-4 hours (small, targeted changes to existing code)

---

## Summary

✅ **Constitution Check**: PASS - All principles satisfied
✅ **Phase 0 Research**: Complete - All unknowns resolved
✅ **Phase 1 Design**: Complete - Data model, contracts, quickstart ready
✅ **Gate Status**: Ready for task generation (`/speckit.tasks`)

**Scope**: Modify JWT generation in step.sh (~50-100 LOC change)
**Risk**: Low - Targeted fix to existing logic, no architectural changes
**Impact**: Fixes intermittent 401 errors caused by clock skew up to ±5 minutes
