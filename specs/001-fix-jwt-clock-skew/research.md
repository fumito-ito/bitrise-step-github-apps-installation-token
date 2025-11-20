# Research: JWT Clock Skew Fix

**Feature**: 001-fix-jwt-clock-skew
**Date**: 2025-11-19
**Status**: Complete

## Purpose

This document consolidates research findings for implementing the JWT clock skew fix. The research focuses on:
1. Best practices for handling clock skew in JWT generation
2. Bash implementations for UTC time retrieval and validation
3. Error detection and diagnostic logging patterns
4. Alignment with octokit/auth-app.js PR #164 approach

## Research Tasks

### 1. JWT Clock Skew Mitigation Patterns

**Question**: What is the industry-standard approach to handling clock skew in JWT generation for API authentication?

**Decision**: Use conservative JWT expiration (5 minutes instead of maximum 10 minutes)

**Rationale**:
- GitHub's API enforces a hard limit of 10 minutes maximum for JWT exp claim
- Clock skew between client and server can be ±5 minutes in typical cloud environments
- By setting exp to iat + 5 minutes, we provide a 5-minute safety buffer
- This approach is used by octokit/auth-app.js (reference implementation) in PR #164
- RFC 7519 recommends clock skew tolerance for distributed systems

**Alternatives Considered**:
1. **Network Time Protocol (NTP) synchronization**: Rejected - adds external dependency and complexity; Bitrise environments may not allow NTP client configuration
2. **Dynamic adjustment based on HTTP Date header**: Rejected - requires additional API call overhead and complicates logic; 5-minute buffer is simpler and sufficient
3. **10-minute expiration (current implementation)**: Rejected - causes 401 errors when local clock is ahead of GitHub's servers

**References**:
- https://github.com/octokit/auth-app.js/pull/164
- RFC 7519 Section 4.1.4 (exp claim) and Section 4.1.6 (iat claim)
- GitHub Apps API documentation on JWT requirements

### 2. UTC Time Retrieval in Bash

**Question**: What is the most reliable cross-platform method to get UTC timestamp in Bash for Linux and macOS?

**Decision**: Use `date -u +%s` for Unix epoch seconds

**Rationale**:
- `date -u +%s` returns Unix epoch seconds in UTC (POSIX standard)
- Works consistently on both Linux (GNU date) and macOS (BSD date)
- No timezone conversion needed - direct UTC output
- Single command execution - fast and efficient
- Already available in Bitrise environments (no new dependency)

**Alternatives Considered**:
1. **`date +%s` (local time)**: Rejected - returns local timezone epoch which requires conversion
2. **`python -c 'import time; print(int(time.time()))'`**: Rejected - adds Python dependency unnecessarily
3. **`gdate` (GNU date on macOS)**: Rejected - not pre-installed on macOS Bitrise runners

**Implementation Pattern**:
```bash
# Get current UTC timestamp
current_time=$(date -u +%s)

# Validate time retrieval succeeded
if [ -z "$current_time" ] || ! [[ "$current_time" =~ ^[0-9]+$ ]]; then
  echo "Error: Failed to retrieve system time" >&2
  exit 1
fi
```

### 3. Extreme Clock Skew Detection

**Question**: How can we detect when system clock is drastically wrong (>1 hour) in a Bash script?

**Decision**: Compare local timestamp against known reasonable range (epoch boundaries)

**Rationale**:
- Extreme clock errors typically manifest as timestamps far in past or future
- Can check if timestamp is before 2020 (epoch: 1577836800) or after 2100 (epoch: 4102444800)
- Provides clear error when clock is years off (more actionable than silent failure)
- Simple integer comparison - no external API calls needed

**Alternatives Considered**:
1. **Query external time API (e.g., worldtimeapi.org)**: Rejected - network dependency, latency, potential failure point
2. **Check against build/release date embedded in script**: Rejected - requires maintaining embedded timestamp
3. **Skip validation**: Rejected - violates FR-007 requirement for detecting extreme clock skew

**Implementation Pattern**:
```bash
# Epoch boundaries
MIN_VALID_EPOCH=1577836800  # 2020-01-01
MAX_VALID_EPOCH=4102444800  # 2100-01-01

if [ "$current_time" -lt "$MIN_VALID_EPOCH" ] || [ "$current_time" -gt "$MAX_VALID_EPOCH" ]; then
  echo "Error: System clock appears to be incorrect (timestamp: $current_time)" >&2
  echo "Please verify system time is set correctly and try again." >&2
  exit 1
fi
```

### 4. Diagnostic Logging for JWT Failures

**Question**: What timing information should be logged when JWT authentication fails to aid debugging?

**Decision**: Log iat, exp, and current_time (UTC epoch seconds) in error messages

**Rationale**:
- iat shows when JWT was issued
- exp shows when JWT expires
- current_time shows system clock at error time
- All three allow user to identify clock skew vs. expiration issues
- Epoch seconds are unambiguous (no timezone confusion)
- Does NOT log JWT payload/signature (security requirement)

**Alternatives Considered**:
1. **Log full JWT payload**: Rejected - security risk (exposes app_id and other claims)
2. **Log only error message without timing**: Rejected - insufficient for troubleshooting clock issues
3. **Log human-readable dates**: Rejected as primary format - timezone ambiguity; epoch is clearer

**Implementation Pattern**:
```bash
# On GitHub API 401 error
if [ "$http_status" = "401" ]; then
  echo "Error: GitHub API authentication failed (401)" >&2
  echo "JWT timing info (UTC epoch seconds):" >&2
  echo "  Issued at (iat): $jwt_iat" >&2
  echo "  Expires at (exp): $jwt_exp" >&2
  echo "  Current time: $(date -u +%s)" >&2
  echo "Possible causes: clock skew, expired JWT, or invalid credentials" >&2
  exit 2
fi
```

### 5. Bash Error Handling for Time Operations

**Question**: How should errors in time retrieval be handled in the context of `set -e`?

**Decision**: Explicit validation after `date` command with descriptive error messages

**Rationale**:
- `set -e` does NOT catch command substitution failures reliably
- Explicit check for empty or non-numeric output ensures robustness
- Provides actionable error message (not just exit code)
- Aligns with existing step.sh validation pattern

**Implementation Pattern**:
```bash
#!/bin/bash
set -e

get_utc_timestamp() {
  local timestamp
  timestamp=$(date -u +%s 2>&1) || {
    echo "Error: Failed to execute 'date -u +%s' command" >&2
    echo "System time utilities may be misconfigured" >&2
    return 1
  }

  if [ -z "$timestamp" ] || ! [[ "$timestamp" =~ ^[0-9]+$ ]]; then
    echo "Error: 'date -u +%s' returned invalid output: '$timestamp'" >&2
    return 1
  fi

  echo "$timestamp"
}
```

## Summary of Decisions

| Aspect | Decision | Impact on Implementation |
|--------|----------|-------------------------|
| JWT exp duration | 5 minutes (iat + 300 seconds) | Change constant in JWT generation function |
| UTC time retrieval | `date -u +%s` | Add time validation function |
| Extreme clock detection | Compare against 2020-2100 epoch range | Add validation check before JWT generation |
| Diagnostic logging | Log iat, exp, current_time on 401 errors | Enhance error handling for GitHub API calls |
| Error handling | Explicit validation with descriptive messages | Add validation functions for time operations |

## Next Steps

- **Phase 1**: Document JWT payload structure (contracts/jwt-payload.json)
- **Phase 1**: Create quickstart guide for testing clock skew scenarios
- **Phase 2**: Break down implementation into specific tasks
