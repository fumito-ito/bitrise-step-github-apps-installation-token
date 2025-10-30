# Tasks: YAML Permissions Format

**Input**: Design documents from `/specs/002-yaml-permissions-format/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/step-io-contract.md

**Tests**: Tests are included as this is a Bitrise step requiring validation of YAML hash format.

**Organization**: Tasks are organized by user story (only 1 story in this simplified version).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1)
- Include exact file paths in descriptions

## Path Conventions

This is a Bitrise step with flat repository structure:
- `step.yml` - Step configuration at repository root
- `step.sh` - Step implementation at repository root
- `README.md` - Documentation at repository root
- `bitrise.yml` - Test workflows at repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Prepare repository and verify current implementation

- [ ] T001 Verify current branch is `002-yaml-permissions-format`
- [ ] T002 [P] Review existing step.yml permissions input configuration in step.yml
- [ ] T003 [P] Review existing permissions validation in step.sh (locate validation logic)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: No foundational tasks needed - all infrastructure exists, this is a configuration enhancement

**Checkpoint**: Foundation ready - user story implementation can begin

---

## Phase 3: User Story 1 - YAML Hash Format for Permissions (Priority: P1) 🎯 MVP

**Goal**: Enable users to specify GitHub App permissions using native YAML hash syntax

**Independent Test**: Configure the step with YAML hash permissions (e.g., `contents: read, metadata: read`) in bitrise.yml test workflow and verify the generated installation token has exactly those permissions via GitHub API query

### Implementation for User Story 1

- [ ] T004 [US1] Set `is_expand: false` for permissions input in step.yml
- [ ] T005 [US1] Update permissions input title/summary to mention YAML hash format in step.yml
- [ ] T006 [US1] Update permissions input description with YAML hash examples in step.yml
- [ ] T007 [US1] (Optional) Enhance permissions validation error message to reference YAML hash format in step.sh
- [ ] T008 [US1] Create test workflow `test-yaml-hash-single-permission` in bitrise.yml for YAML hash with single permission
- [ ] T009 [US1] Create test workflow `test-yaml-hash-multiple-permissions` in bitrise.yml for YAML hash with multiple read/write permissions
- [ ] T010 [US1] Create test workflow `test-yaml-hash-write-permissions` in bitrise.yml for YAML hash with write permissions
- [ ] T011 [US1] Update README.md introduction section to show YAML hash format as primary example
- [ ] T012 [US1] Add YAML hash examples section to README.md with various permission combinations

**Checkpoint**: At this point, User Story 1 should be fully functional - YAML hash format works, is tested, and is documented

---

## Phase 4: Polish & Cross-Cutting Concerns

**Purpose**: Edge case testing and final documentation polish

- [ ] T013 [P] Create test workflow `test-empty-permissions` in bitrise.yml to verify omitted permissions behavior
- [ ] T014 [P] Create test workflow `test-invalid-json` in bitrise.yml to verify error handling
- [ ] T015 [P] Add YAML hash troubleshooting section to README.md (indentation, syntax errors)
- [ ] T016 [P] Add common permissions reference table to README.md
- [ ] T017 Verify all test workflows pass (run `bitrise run test-yaml-hash-single-permission test-yaml-hash-multiple-permissions test-yaml-hash-write-permissions`)
- [ ] T018 Review quickstart.md examples and ensure they match implemented step.yml configuration
- [ ] T019 Update CHANGELOG.md with new YAML hash format feature description
- [ ] T020 Final review: Verify step.yml, README.md, and test workflows are consistent

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: No tasks (existing infrastructure sufficient)
- **User Story 1 (Phase 3)**: Can start after Setup - No dependencies on other stories
- **Polish (Phase 4)**: Depends on User Story 1 being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Setup (Phase 1) - No dependencies (this is the only user story)

### Within User Story 1

**Execution order**:
1. Update step.yml configuration (T004, T005, T006) - can be done in parallel
2. (Optional) Update step.sh error message (T007)
3. Create test workflows (T008, T009, T010) - can be done in parallel after step.yml updates
4. Update README.md (T011, T012) - can be done in parallel after step.yml updates

### Parallel Opportunities

- Within Phase 1: T002 and T003 can run in parallel (review tasks)
- Within User Story 1: T004-T006 can be done in parallel (all step.yml edits)
- Within User Story 1: T008-T010 can be done in parallel (all test workflow creation)
- Within User Story 1: T011-T012 can be done in parallel (all README.md edits)
- Within Polish phase: T013-T016 can all be done in parallel (different files or sections)

---

## Parallel Example: User Story 1

```bash
# Launch all step.yml configuration updates together:
Task: "Set is_expand: false for permissions input in step.yml"
Task: "Update permissions input title/summary to mention YAML hash format"
Task: "Update permissions input description with YAML hash examples"

# Launch all test workflow creation together:
Task: "Create test workflow test-yaml-hash-single-permission in bitrise.yml"
Task: "Create test workflow test-yaml-hash-multiple-permissions in bitrise.yml"
Task: "Create test workflow test-yaml-hash-write-permissions in bitrise.yml"

# Launch all README.md updates together:
Task: "Update README.md introduction section to show YAML hash format"
Task: "Add YAML hash examples section to README.md with various combinations"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T003) - ~10 minutes
2. Complete Phase 3: User Story 1 (T004-T012) - ~1.5 hours
3. **STOP and VALIDATE**: Test User Story 1 independently
4. Run test workflows and verify YAML hash format works
5. Review documentation for clarity

### Incremental Delivery

1. Complete Setup (Phase 1) → Repository ready
2. Add User Story 1 (Phase 3) → YAML hash format works → Test independently → Deploy (MVP!)
3. Add Polish (Phase 4) → Edge cases covered, documentation polished → Deploy

### Sequential Single-Developer Strategy

Recommended execution order for one developer:

1. **Phase 1: Setup** (T001-T003) - ~10 minutes
   - Verify branch, review existing configuration

2. **Phase 3: User Story 1** (T004-T012) - ~1.5 hours
   - Update step.yml (T004-T006) - ~20 minutes
   - (Optional) Enhance error message (T007) - ~5 minutes
   - Create test workflows (T008-T010) - ~30 minutes
   - Update README.md (T011-T012) - ~35 minutes
   - **Validate**: Run test workflows, verify YAML hash works

3. **Phase 4: Polish** (T013-T020) - ~1 hour
   - Edge case tests (T013-T014) - ~20 minutes
   - Documentation polish (T015-T016) - ~20 minutes
   - Final validation (T017-T020) - ~20 minutes

**Total Estimated Time**: ~2.5-3 hours

---

## Key Technical Decisions from Research

Based on research.md findings, implementation is simplified:

1. **No format detection needed**: Bitrise automatically serializes YAML hashes to JSON strings
2. **No conversion code needed**: Existing validation already handles JSON (jq empty check)
3. **Primary changes are configuration**: step.yml documentation and `is_expand: false` setting
4. **Error message enhancement is optional**: Existing validation works, enhancement improves UX
5. **Focus is on examples and tests**: Show users the YAML hash format through documentation

**Key Research Finding**: When users specify a YAML hash in bitrise.yml:
```yaml
permissions:
  contents: read
  issues: write
```

Bitrise serializes this to:
```bash
permissions='{"contents":"read","issues":"write"}'
```

So step.sh receives a JSON string regardless of input format. This means:
- ✅ Existing `jq empty` validation works for YAML hash
- ✅ Existing wrapping logic works: `{"permissions":${permissions}}`
- ✅ No code changes needed beyond optional error message enhancement

---

## Notes

- [P] tasks = different files or sections, no dependencies
- [US1] label maps task to User Story 1 for traceability
- User Story 1 is the only story (simplified from original 2-story spec)
- Test workflows validate functionality at each checkpoint
- Primary work is configuration (step.yml) and documentation (README.md, examples)
- Minimal or no code changes to step.sh (only optional error message enhancement)
- Total of 20 tasks (reduced from 24 in original dual-format spec)
- No backward compatibility tasks (step not published yet)
