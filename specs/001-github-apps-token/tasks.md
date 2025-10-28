# Tasks: GitHub Apps Installation Token Generator

**Input**: Design documents from `/specs/001-github-apps-token/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Not requested in specification - implementation-focused approach

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Bitrise steps use flat structure at repository root:
- **step.sh**: Main implementation
- **step.yml**: Step definition (inputs/outputs)
- **bitrise.yml**: Test workflows

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Update step.yml with correct title, summary, and description
- [ ] T002 Define input parameters in step.yml (app_id, installation_id, private_pem, permissions)
- [ ] T003 Define output parameter in step.yml (GITHUB_APPS_INSTALLATION_TOKEN)
- [ ] T004 Update bitrise.yml with test workflow for valid credentials scenario
- [ ] T005 Create .bitrise.secrets.yml template with placeholder credentials in README.md

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T006 Implement base64url encoding function in step.sh
- [ ] T007 Implement cleanup trap handler for EXIT/ERR/INT/TERM signals in step.sh
- [ ] T008 Implement tool validation (openssl, curl, jq, envman, base64) in step.sh
- [ ] T009 Implement PEM normalization function (trim whitespace, normalize line breaks) in step.sh
- [ ] T010 Implement input validation function for app_id and installation_id (non-empty, numeric) in step.sh
- [ ] T011 Implement PEM validation function (BEGIN/END markers check) in step.sh

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - Generate Installation Token with Basic Inputs (Priority: P1) 🎯 MVP

**Goal**: Generate GitHub Apps Installation Token from App ID, Installation ID, and private PEM key

**Independent Test**: Run `bitrise run test` with valid credentials in `.bitrise.secrets.yml` and verify GITHUB_APPS_INSTALLATION_TOKEN is exported

### Implementation for User Story 1

- [ ] T012 [US1] Implement JWT header creation function in step.sh
- [ ] T013 [US1] Implement JWT payload creation with iat/exp/iss claims in step.sh
- [ ] T014 [US1] Implement temporary PEM file creation with mktemp and chmod 0600 in step.sh
- [ ] T015 [US1] Implement JWT signing with openssl dgst -sha256 -sign in step.sh
- [ ] T016 [US1] Implement complete JWT generation function (header.payload.signature) in step.sh
- [ ] T017 [US1] Implement GitHub API call with curl (POST /app/installations/{id}/access_tokens) in step.sh
- [ ] T018 [US1] Implement HTTP response parsing (status code and body separation) in step.sh
- [ ] T019 [US1] Implement token extraction from JSON response using jq in step.sh
- [ ] T020 [US1] Implement envman export with exit code validation in step.sh
- [ ] T021 [US1] Implement success logging (non-sensitive: expiration time, confirmation message) in step.sh
- [ ] T022 [US1] Add set +x around sensitive operations (JWT generation, API call, token export) in step.sh

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently

---

## Phase 4: User Story 2 - Custom Permission Scopes (Priority: P2)

**Goal**: Allow users to restrict installation token to specific permissions for least-privilege security

**Independent Test**: Run `bitrise run test-permissions` with permissions='{"contents":"read"}' and verify token has only requested permissions via GitHub API query

### Implementation for User Story 2

- [ ] T023 [US2] Add permissions parameter validation (valid JSON if provided) in step.sh
- [ ] T024 [US2] Implement permissions JSON construction for API request body in step.sh
- [ ] T025 [US2] Update GitHub API call to include permissions in request body when provided in step.sh
- [ ] T026 [US2] Update bitrise.yml with test-permissions workflow using custom permissions
- [ ] T027 [US2] Add verification script in bitrise.yml to check token permissions via GitHub API

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently

---

## Phase 5: User Story 3 - Helpful Error Messages and Validation (Priority: P3)

**Goal**: Provide clear, actionable error messages for all failure scenarios

**Independent Test**: Run test workflows for each error scenario (missing inputs, invalid formats, API errors) and verify specific error messages appear

### Implementation for User Story 3

- [ ] T028 [US3] Implement error message function for missing app_id in step.sh
- [ ] T029 [US3] Implement error message function for non-numeric app_id in step.sh
- [ ] T030 [US3] Implement error message function for missing installation_id in step.sh
- [ ] T031 [US3] Implement error message function for non-numeric installation_id in step.sh
- [ ] T032 [US3] Implement error message function for missing private_pem in step.sh
- [ ] T033 [US3] Implement error message function for invalid PEM format in step.sh
- [ ] T034 [US3] Implement network error handling with actionable message in step.sh
- [ ] T035 [US3] Implement GitHub API error parsing (401, 404, 403, 422) with context in step.sh
- [ ] T036 [US3] Implement rate limit / 503 error detection in step.sh
- [ ] T037 [US3] Implement 5-second wait and single retry logic for 503/429 errors in step.sh
- [ ] T038 [US3] Implement error message relay for API permission rejections (FR-018) in step.sh
- [ ] T039 [US3] Implement envman export failure detection and error message in step.sh
- [ ] T040 [US3] Add test workflows to bitrise.yml for error scenarios (missing inputs, invalid formats, etc.)

**Checkpoint**: All user stories should now be independently functional with comprehensive error handling

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories and final documentation

- [ ] T041 Add script header comments with usage examples to step.sh
- [ ] T042 Update README.md with setup instructions (GitHub App creation, credentials)
- [ ] T043 Update README.md with usage examples (basic, custom permissions)
- [ ] T044 Update README.md with troubleshooting section (common errors and solutions)
- [ ] T045 Add example .bitrise.secrets.yml format to README.md
- [ ] T046 Document exit codes (0=success, 1=validation, 2=API error, 3=envman) in README.md
- [ ] T047 Verify step.yml has accurate descriptions and examples for all inputs
- [ ] T048 Verify all logging uses appropriate log levels (errors to stderr, info to stdout)
- [ ] T049 Run quickstart.md validation scenarios to verify end-to-end functionality
- [ ] T050 Run bitrise run audit-this-step to validate step.yml compliance

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-5)**: All depend on Foundational phase completion
  - User stories can then proceed in parallel (if staffed)
  - Or sequentially in priority order (P1 → P2 → P3)
- **Polish (Phase 6)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P2)**: Can start after Foundational (Phase 2) - Extends US1 but independently testable
- **User Story 3 (P3)**: Can start after Foundational (Phase 2) - Enhances all stories but independently testable

### Within Each User Story

- **US1**: Sequential flow (validation → JWT → API → export → logging)
- **US2**: Extends US1 API call logic
- **US3**: Adds error handling to all US1/US2 operations

### Parallel Opportunities

- Setup tasks (T001-T005): Some can run in parallel but are fast enough to run sequentially
- Foundational tasks (T006-T011): Can mostly run in parallel as they're independent functions
- Within US3 error messages (T028-T039): Many can be implemented in parallel as they're independent error handlers
- Polish tasks (T041-T050): Documentation tasks (T042-T046) can run in parallel

---

## Parallel Example: Foundational Phase

```bash
# These foundational functions can be implemented in parallel:
Task T006: base64url_encode() function
Task T007: cleanup() trap handler function
Task T008: validate_tools() function
Task T009: normalize_pem() function
Task T010: validate_numeric_input() function
Task T011: validate_pem_format() function
```

---

## Parallel Example: User Story 3 Error Messages

```bash
# These error message implementations can be done in parallel:
Task T028: error_missing_app_id()
Task T029: error_invalid_app_id()
Task T030: error_missing_installation_id()
Task T031: error_invalid_installation_id()
Task T032: error_missing_pem()
Task T033: error_invalid_pem_format()
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test User Story 1 independently with `bitrise run test`
5. Verify token generation works end-to-end
6. Deploy/demo if ready

**This gives you a working Bitrise step that generates installation tokens!**

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test independently → Deploy/Demo (MVP!)
3. Add User Story 2 → Test independently → Deploy/Demo (security enhancement)
4. Add User Story 3 → Test independently → Deploy/Demo (UX improvement)
5. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (core functionality)
   - Developer B: User Story 3 error messages (can work in parallel with A)
   - Developer C: User Story 2 (can start after US1 API call is defined)
3. Stories complete and integrate independently

---

## Testing Strategy

### Manual Testing Workflow

1. **Setup**: Create `.bitrise.secrets.yml` with real GitHub App credentials
2. **US1 Test**: Run `bitrise run test` - verify token exported
3. **US2 Test**: Run `bitrise run test-permissions` - verify permission scoping works
4. **US3 Test**: Run error scenario workflows - verify error messages are clear

### Validation Checklist

After completing each user story:

- [ ] Step executes successfully with valid inputs
- [ ] Step exports GITHUB_APPS_INSTALLATION_TOKEN correctly
- [ ] Generated token works with GitHub API (test with curl)
- [ ] No sensitive data in step logs
- [ ] Temporary files cleaned up (check /tmp after run)
- [ ] Exit codes correct (0 for success, non-zero for failures)
- [ ] Error messages actionable (user knows what to fix)

---

## File Modification Summary

**Files to be created/modified**:

| File | Modifications | User Stories |
|------|---------------|--------------|
| step.sh | Core implementation (all functions) | US1, US2, US3 |
| step.yml | Inputs/outputs/metadata | US1, US2 |
| bitrise.yml | Test workflows | US1, US2, US3 |
| README.md | Documentation | All |

**No new files to create** - Bitrise step structure uses existing files at repository root.

---

## Notes

- **No [P] markers on user story tasks**: Tasks within a story are sequential (each builds on previous)
- **Foundational phase can have [P]**: Independent utility functions can be written in parallel
- **Error handling (US3)**: Many error handlers can be written in parallel
- **Each user story = independently testable increment**
- **Stop at any checkpoint to validate story independently**
- **Commit after each completed user story**
- **Avoid: implementing US2/US3 before US1 foundation is complete**

---

## Success Criteria Mapping

| Success Criterion | Validated By | Task(s) |
|-------------------|--------------|---------|
| SC-001: <30 second token generation | Manual timing test | T012-T020 (US1) |
| SC-002: 95% success rate with valid creds | Statistical testing over multiple runs | T012-T020 (US1) |
| SC-003: Self-service error resolution | Error message clarity testing | T028-T039 (US3) |
| SC-004: 1-hour token expiration | API response validation | T019, T021 (US1) |
| SC-005: No sensitive data in logs | Log inspection after run | T022 (US1) |
| SC-006: 100% temp file cleanup | /tmp inspection after run | T007, T014 (Foundation, US1) |
| SC-007: Permission scoping works | Token permission query via API | T023-T027 (US2) |

---

## Ready for Implementation

All tasks are defined with:
- ✅ Clear descriptions
- ✅ Exact file paths
- ✅ User story mapping
- ✅ Dependencies identified
- ✅ Parallel opportunities noted
- ✅ Independent test criteria per story
- ✅ MVP scope clearly marked (User Story 1)

**Next Steps**: Start with Phase 1 (Setup), then Phase 2 (Foundational), then Phase 3 (User Story 1 - MVP).
