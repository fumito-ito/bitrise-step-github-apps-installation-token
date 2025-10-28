# Implementation Plan: GitHub Apps Installation Token Generator

**Branch**: `001-github-apps-token` | **Date**: 2025-10-28 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-github-apps-token/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Generate GitHub Apps Installation Tokens in Bitrise workflows by accepting App ID, Installation ID, and private PEM key as inputs. The step creates a JWT signed with RS256, exchanges it for an installation access token via GitHub's REST API, and exports the token to GITHUB_APPS_INSTALLATION_TOKEN environment variable. Implementation uses shell script (step.sh) with openssl for JWT signing, curl for API calls, and jq for JSON parsing. Security features include PEM key normalization, no logging of sensitive data, secure temp file handling with 0600 permissions, and cleanup on all exit paths including retry logic for transient failures.

## Technical Context

**Language/Version**: Bash 4.x+ (POSIX-compatible shell script)
**Primary Dependencies**: openssl (RS256 JWT signing), curl (GitHub API calls), jq (JSON parsing), envman (Bitrise environment management - pre-installed)
**Storage**: N/A (stateless operation, temporary files only for PEM key during JWT generation)
**Testing**: Bitrise CLI with bitrise.yml test workflows, manual testing with .bitrise.secrets.yml
**Target Platform**: Bitrise CI/CD environment (Linux and macOS stacks)
**Project Type**: Bitrise Step (single shell script entry point)
**Performance Goals**: Token generation in <30 seconds with valid credentials (SC-001)
**Constraints**: Must not log sensitive data, temp files must use 0600 permissions, must cleanup on all exit paths, requires network connectivity to api.github.com
**Scale/Scope**: Single-purpose utility step, no horizontal scaling concerns, supports all Bitrise project types

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

✅ **All constitution checks passed - no violations**

**Shell-First Development (Principle I)**:
- [x] Implementation uses shell scripts (step.sh) as primary implementation language
- [x] External dependencies are minimal and justified (openssl, curl, jq - all standard Unix tools)
- [x] No complex language-specific tooling required

**Bitrise Step Standards Compliance (Principle II)**:
- [x] step.yml defines all inputs/outputs according to Bitrise spec (FR-001 to FR-004, FR-008)
- [x] Inputs accessed via environment variables (per Bitrise convention)
- [x] Outputs use envman for export (FR-008)
- [x] Metadata (title, summary, description) is complete and accurate

**Secure Credential Handling (Principle III - NON-NEGOTIABLE)**:
- [x] Private keys/tokens passed via secure environment variables (FR-003)
- [x] No sensitive data logged to stdout/stderr (FR-009)
- [x] Temporary files with sensitive data have 0600 permissions (FR-010)
- [x] Cleanup of sensitive data on all exit paths (FR-011)
- [x] All GitHub API calls use HTTPS (curl with https://api.github.com)

**Clear Input/Output Contract (Principle IV)**:
- [x] All required inputs validated at start (FR-005, FR-015)
- [x] Validation failures exit with non-zero status (FR-012)
- [x] Error messages are actionable (FR-013, FR-014, FR-018)
- [x] Success confirmation provided (logged output on successful token generation)

**Error Handling & Exit Codes (Principle V)**:
- [x] Exit code 0 for success, non-zero for failure (FR-012)
- [x] set -e used for fail-fast behavior (step.sh template pattern)
- [x] Network/API/validation errors caught and reported (FR-013, FR-014)
- [x] Cleanup actions run on failure (FR-011, trap handlers)

## Project Structure

### Documentation (this feature)

```text
specs/001-github-apps-token/
├── spec.md              # Feature specification (complete)
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   ├── github-api-contract.md
│   └── step-io-contract.md
├── checklists/          # Quality validation
│   └── requirements.md  # Specification validation checklist (complete)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

Bitrise steps use a flat structure at repository root following Bitrise conventions:

```text
bitrise-step-github-apps-installation-token/
├── step.sh                # Main implementation script (to be updated)
├── step.yml               # Bitrise step definition (to be updated with inputs/outputs)
├── bitrise.yml            # Test workflows (to be updated with test scenarios)
├── .gitignore             # Git ignore patterns
├── .bitrise.secrets.yml   # Local testing secrets (git-ignored, user-created)
├── README.md              # Usage documentation (to be updated)
├── LICENSE                # License file
└── specs/                 # Feature specifications (this directory)
    └── 001-github-apps-token/
```

**Structure Decision**: Bitrise steps do not use src/ or tests/ directories. Implementation goes directly in step.sh at repository root, and testing is performed via bitrise.yml workflows. This aligns with Bitrise Step Development Guidelines and constitution Principle II (Bitrise Step Standards Compliance). The flat structure makes the step easy to reference in workflows and simple to maintain.

## Complexity Tracking

No constitution violations - this section is not applicable.
