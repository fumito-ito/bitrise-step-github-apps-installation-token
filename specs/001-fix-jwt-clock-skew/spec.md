# Feature Specification: Fix JWT Clock Skew Errors

**Feature Branch**: `001-fix-jwt-clock-skew`
**Created**: 2025-11-19
**Status**: Draft
**Input**: User description: "Fix intermittent 401 errors from JWT exp claim clock skew"
**Related Issue**: https://github.com/fumito-ito/bitrise-step-github-apps-installation-token/issues/3

## Clarifications

### Session 2025-11-19

- Q: What happens when the system clock is drastically incorrect (e.g., years off)? → A: システムクロックが1時間以上ずれている場合はエラーを出して処理を中断する
- Q: How does the system handle time zone differences versus actual clock skew? → A: すべてのタイムスタンプをUTC（協定世界時）で扱い、タイムゾーンは考慮しない
- Q: What happens if the JWT generation timestamp retrieval fails? → A: システムエラーとして処理を中断し、明確なエラーメッセージを表示する
- Q: How does the system behave during leap seconds or daylight saving time transitions? → A: UTC使用により、うるう秒やサマータイムは自動的に正しく処理される（追加処理不要）

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Reliable Token Generation (Priority: P1)

When a Bitrise workflow runs and needs to obtain a GitHub Apps installation token, the token generation must succeed consistently regardless of minor clock differences between the execution environment and GitHub's servers.

**Why this priority**: This is the core functionality of the step. Without reliable token generation, the step fails its primary purpose, blocking CI/CD workflows.

**Independent Test**: Can be fully tested by running the step multiple times in different execution environments (with varying system clocks) and verifying that token generation succeeds in all cases, delivering immediate workflow reliability.

**Acceptance Scenarios**:

1. **Given** the Bitrise step is executing on a server with a system clock slightly ahead of GitHub's servers (within 5 minutes), **When** the step generates a JWT for authentication, **Then** the JWT exp claim is set conservatively to avoid exceeding GitHub's 10-minute tolerance window
2. **Given** the Bitrise step is executing on a server with a system clock slightly behind GitHub's servers (within 5 minutes), **When** the step generates a JWT for authentication, **Then** the JWT is still valid and accepted by GitHub's API
3. **Given** the Bitrise step generates a JWT and calls GitHub's installation token API, **When** there is clock skew up to 5 minutes in either direction, **Then** the API call succeeds with a 2xx status code and returns a valid installation token

---

### User Story 2 - Clear Error Diagnostics (Priority: P2)

When token generation fails due to clock-related issues, users receive clear diagnostic information to understand and resolve the problem.

**Why this priority**: While preventing failures is primary, helping users diagnose and recover from failures when they do occur improves the overall developer experience and reduces support burden.

**Independent Test**: Can be tested independently by simulating extreme clock skew scenarios and verifying that error messages provide actionable guidance.

**Acceptance Scenarios**:

1. **Given** the system clock is more than 10 minutes ahead of GitHub's servers, **When** token generation fails with a 401 error, **Then** the error message clearly indicates a clock skew issue and suggests verification of system time
2. **Given** a JWT-related authentication failure occurs, **When** the step logs the error, **Then** the log includes relevant timing information (JWT iat, exp claims and current time) to aid debugging

---

### Edge Cases

- **Extreme clock errors**: System MUST detect when the local clock differs from a reasonable time range (>1 hour variance) and fail with a clear error message indicating system time misconfiguration before attempting JWT generation
- **Time zone handling**: All timestamps (iat, exp) MUST be generated using UTC (Coordinated Universal Time) per JWT standard (RFC 7519); local time zones are not considered
- **Timestamp retrieval failure**: If UTC timestamp cannot be retrieved from the system, the step MUST abort immediately with a clear error message indicating the system time access failure and suggesting environment diagnostics
- **Leap seconds and DST**: By using UTC and Unix epoch seconds per RFC 7519, leap seconds and daylight saving time transitions are automatically handled correctly without additional processing; no special logic required

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST generate JWT tokens with exp claim set to 5 minutes from the iat claim (half of GitHub's 10-minute maximum) to provide a safety margin for clock skew
  - *Acceptance: Verified by User Story 1, Acceptance Scenario 1*
- **FR-002**: System MUST set JWT iat (issued at) claim to the current UTC timestamp (Unix epoch seconds) at time of token generation
  - *Acceptance: Verified by User Story 1, Acceptance Scenarios 1-3*
- **FR-003**: System MUST ensure JWT exp claim never exceeds 10 minutes from the iat claim to comply with GitHub's API requirements
  - *Acceptance: Verified by User Story 1, Acceptance Scenarios 1-3*
- **FR-004**: System MUST handle GitHub API 401 errors related to JWT expiration gracefully with informative error messages
  - *Acceptance: Verified by User Story 2, Acceptance Scenario 1*
- **FR-005**: System MUST log relevant timing information (iat, exp, current time) when JWT authentication fails
  - *Acceptance: Verified by User Story 2, Acceptance Scenario 2*
- **FR-006**: System MUST validate that system time can be retrieved before attempting JWT generation
  - *Acceptance: System exits with clear error message if time retrieval fails*
- **FR-007**: System MUST detect extreme clock skew (>1 hour from expected range) and abort with a clear error message before attempting JWT generation
  - *Acceptance: System fails fast with diagnostic message when clock variance exceeds 1 hour*

### Assumptions

- The execution environment has access to UTC time via standard Unix commands (e.g., `date -u`)
- Clock skew is typically within ±5 minutes in normal operating conditions
- GitHub's 10-minute maximum for JWT exp claim is a hard limit enforced by their API
- The solution follows the pattern used in similar projects (e.g., octokit/auth-app.js PR #164)
- JWT timestamps follow RFC 7519 standard (Unix epoch seconds in UTC)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Token generation succeeds in at least 99.9% of workflow executions across different execution environments
- **SC-002**: Zero 401 errors occur due to JWT exp claim issues when system clock skew is within ±5 minutes
- **SC-003**: When JWT-related failures do occur, 100% of error logs include diagnostic timing information (iat, exp, current time)
- **SC-004**: Users can identify and understand clock-related issues within 5 minutes when reviewing error logs
