# Tasks: Fix JWT Clock Skew Errors

**Input**: Design documents from `/specs/001-fix-jwt-clock-skew/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Manual testing per quickstart.md - no automated test framework requested

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2)
- Include exact file paths in descriptions

## Path Conventions

This is a single-file Bitrise step project:
- Main implementation: `step.sh` (repository root)
- No separate test directory - manual testing via `bitrise run test`

---

## Phase 1: Setup (Preparation)

**Purpose**: Analyze existing code and prepare for modifications

- [x] T001 Review existing JWT generation logic in step.sh (lines 165-234, functions: create_jwt_payload, generate_jwt)
- [x] T002 Identify current exp calculation location in step.sh:create_jwt_payload() function
- [x] T003 Review existing error handling patterns in step.sh (functions: handle_api_error, validate_*)

**Checkpoint**: ✅ Understanding of current implementation complete

---

## Phase 2: Foundational (UTC Time Infrastructure)

**Purpose**: Add UTC timestamp validation infrastructure needed by ALL user stories

**⚠️ CRITICAL**: These functions MUST be complete before any user story implementation

- [x] T004 Add MIN_VALID_EPOCH and MAX_VALID_EPOCH constants at top of step.sh (after readonly declarations, ~line 50)
- [x] T005 Create get_utc_timestamp() function in step.sh after validate_pem() function (~line 160)
- [x] T006 Create validate_utc_timestamp() function in step.sh after get_utc_timestamp() function

**Checkpoint**: ✅ UTC time infrastructure ready - user story implementation can begin

---

## Phase 3: User Story 1 - Reliable Token Generation (Priority: P1) 🎯 MVP

**Goal**: Fix intermittent 401 errors by adjusting JWT exp to 5 minutes and ensuring UTC time usage

**Independent Test**: Run `bitrise run test` multiple times - token generation should succeed consistently. Manually adjust system clock ±5 minutes per quickstart.md scenarios 1 and 2 to verify tolerance.

### Implementation for User Story 1

- [x] T007 [US1] Modify create_jwt_payload() function in step.sh to call get_utc_timestamp() for iat value
- [x] T008 [US1] Modify create_jwt_payload() function in step.sh to change exp calculation from iat+600 to iat+300
- [x] T009 [US1] Add validate_utc_timestamp() call in generate_jwt() function before create_jwt_payload()
- [x] T010 [US1] Update JWT payload generation to ensure iat uses UTC (verify `date -u` usage in get_utc_timestamp)
- [x] T011 [US1] Verify exp-iat constraint (300 seconds) in generate_jwt() function after payload creation

**Verification Checklist for US1**:
- [x] JWT exp = iat + 300 (not 600)
- [x] iat value comes from `date -u +%s` (UTC, not local time)
- [x] Timestamp validation occurs before JWT generation
- [x] Extreme clock errors (>1 hour) detected and reported

**Checkpoint**: ✅ User Story 1 complete - token generation works with ±5 minute clock skew

---

## Phase 4: User Story 2 - Clear Error Diagnostics (Priority: P2)

**Goal**: Provide diagnostic timing information when authentication fails

**Independent Test**: Use invalid App ID per quickstart.md scenario 6 - error output should include "JWT timing info" with iat, exp, and current_time values

### Implementation for User Story 2

- [x] T012 [US2] Store jwt_iat and jwt_exp values in generate_jwt() function after payload creation
- [x] T013 [US2] Pass jwt_iat and jwt_exp to call_github_api() function (modify function signature)
- [x] T014 [US2] Modify handle_api_error() function in step.sh to accept jwt_iat and jwt_exp parameters
- [x] T015 [US2] Add diagnostic logging block in handle_api_error() for 401 errors with format:
  ```
  JWT timing info (UTC epoch seconds):
    Issued at (iat): $jwt_iat
    Expires at (exp): $jwt_exp
    Current time: $(date -u +%s)
  ```
- [x] T016 [US2] Verify no JWT token string is logged (only iat/exp numeric values)
- [x] T017 [US2] Add "Possible causes: clock skew, expired JWT, or invalid credentials" hint to 401 error message

**Verification Checklist for US2**:
- [x] 401 errors display iat, exp, current_time
- [x] All timing values are UTC epoch seconds
- [x] No JWT token string appears in logs
- [x] Error message provides actionable guidance

**Checkpoint**: ✅ User Story 2 complete - clear diagnostics for troubleshooting

---

## Phase 5: Polish & Verification

**Purpose**: Final validation, documentation, and edge case handling

- [ ] T018 Add comments documenting clock skew fix in step.sh (at create_jwt_payload and validate_utc_timestamp functions)
- [ ] T019 Verify all error messages reference "UTC" where appropriate for clarity
- [ ] T020 Review security: confirm no sensitive data (private key, JWT token) logged anywhere
- [ ] T021 Test normal operation scenario (quickstart.md scenario 1)
- [ ] T022 Test clock skew future scenario (quickstart.md scenario 1: +5 minutes)
- [ ] T023 Test clock skew past scenario (quickstart.md scenario 2: -3 minutes)
- [ ] T024 Test extreme clock error scenario (quickstart.md scenario 3: year 2000)
- [ ] T025 Test UTC vs local time scenario (quickstart.md scenario 4: set TZ=Asia/Tokyo)
- [ ] T026 Test 401 diagnostic logging scenario (quickstart.md scenario 6: invalid App ID)
- [ ] T027 Verify performance benchmark (quickstart.md scenario 7: complete within 5 seconds)
- [ ] T028 Run regression tests (quickstart.md scenario 8: existing functionality still works)
- [ ] T029 Update README.md troubleshooting section with clock skew guidance (optional)

---

## Dependencies & Execution Strategy

### User Story Dependency Graph

```
Setup (Phase 1) → Foundational (Phase 2) → User Story 1 (Phase 3) → User Story 2 (Phase 4) → Polish (Phase 5)
                                                ↓
                                         (P1 - MVP Core)
```

**Critical Path**: Setup → Foundational → US1 → US2 → Polish (linear for this small fix)

**Parallel Opportunities**: Limited due to single-file modification, but within phases:
- Phase 5: Test scenarios (T021-T028) can be run in parallel

### Implementation Strategy

**MVP Scope** (Minimum Viable Product):
- **Phase 1-3 only** (T001-T011): Core clock skew fix
- Delivers: JWT exp = iat + 300, UTC enforcement, extreme clock detection
- Independent test: Token generation succeeds with ±5 min clock skew

**Full Feature** (P1 + P2):
- **Phase 1-4** (T001-T017): MVP + diagnostic logging
- Delivers: All functionality from spec
- Independent test: Both US1 and US2 acceptance criteria met

**Production Ready**:
- **All phases** (T001-T029): Full feature + polish + verification
- Delivers: Tested, documented, production-ready implementation

### Recommended Execution Order

1. **Start with MVP**: Complete T001-T011 first
   - Test US1 independently (scenarios 1-3 from quickstart.md)
   - If successful, you have a shippable increment

2. **Add Diagnostics**: Complete T012-T017
   - Test US2 independently (scenario 6 from quickstart.md)
   - Now both stories are complete

3. **Polish**: Complete T018-T029
   - Full test suite
   - Documentation updates
   - Ready for production

### Parallel Execution Examples

**Phase 2 (if multiple developers)**:
- Dev A: T004, T005
- Dev B: T006
- Both tasks modify step.sh in different areas (constants vs. functions)

**Phase 5 (Testing)**:
- All test tasks (T021-T028) can run in parallel if you have multiple test environments
- Each tests a different scenario from quickstart.md

---

## Task Summary

**Total Tasks**: 29
- Setup: 3 tasks
- Foundational: 3 tasks
- User Story 1 (P1 - MVP): 5 tasks
- User Story 2 (P2): 6 tasks
- Polish & Verification: 12 tasks

**Estimated Effort**:
- MVP (T001-T011): 1-2 hours
- Full Feature (T001-T017): 2-3 hours
- Production Ready (T001-T029): 3-4 hours

**Parallel Opportunities**: 8 test scenarios in Phase 5 can run concurrently

**Critical Dependencies**:
- T005-T006 must complete before T007-T011 (UTC functions needed by US1)
- T007-T011 must complete before T012-T017 (US2 needs iat/exp from US1)
- T001-T017 should complete before T018-T029 (polish requires working implementation)

---

## Validation

All tasks follow the required format:
✅ Checkbox format: `- [ ]`
✅ Task IDs: T001-T029 (sequential)
✅ [P] markers: None (single file, mostly sequential dependencies)
✅ [Story] labels: [US1] for Phase 3, [US2] for Phase 4
✅ File paths: step.sh explicitly mentioned in all implementation tasks
✅ Descriptions: Clear actions with specific function names and line references
