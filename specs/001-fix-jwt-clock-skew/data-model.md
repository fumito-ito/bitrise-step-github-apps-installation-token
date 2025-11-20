# Data Model: JWT Clock Skew Fix

**Feature**: 001-fix-jwt-clock-skew
**Date**: 2025-11-19

## Overview

This feature modifies the JWT generation process to handle clock skew. The data model focuses on the temporal aspects of JWT claims and timing validation. There are no new persistent entities - all data is ephemeral (in-memory during script execution).

## Entities

### 1. UTC Timestamp

**Description**: Unix epoch seconds in UTC, used for all JWT timing calculations

**Type**: Integer (positive)

**Source**: `date -u +%s` command output

**Validation Rules**:
- Must be numeric (regex: `^[0-9]+$`)
- Must be >= 1577836800 (2020-01-01 00:00:00 UTC)
- Must be <= 4102444800 (2100-01-01 00:00:00 UTC)
- Must be retrievable from system (non-empty output from `date -u`)

**Usage**:
- JWT `iat` (issued at) claim
- JWT `exp` (expires at) claim calculation (iat + 300)
- Current time logging for diagnostics

**Lifetime**: Script execution duration (stored in bash variables)

---

### 2. JWT Header

**Description**: JWT header containing algorithm and type per RFC 7519

**Structure**:
```json
{
  "alg": "RS256",
  "typ": "JWT"
}
```

**Fields**:
- `alg` (string, fixed): "RS256" - RSA signature with SHA-256
- `typ` (string, fixed): "JWT" - token type

**Encoding**: Base64URL (RFC 4648 Section 5)

**Changes**: None (existing implementation remains)

---

### 3. JWT Payload

**Description**: JWT claims including timing fields (modified for clock skew fix)

**Structure** (modified fields highlighted):
```json
{
  "iat": 1700000000,        // *** MODIFIED: Ensured to be UTC epoch
  "exp": 1700000300,        // *** MODIFIED: Changed from iat+600 to iat+300
  "iss": "123456"           // GitHub App ID (unchanged)
}
```

**Fields**:
- `iat` (integer, required): Issued At time in UTC epoch seconds
  - **Source**: `date -u +%s`
  - **Validation**: Must pass UTC Timestamp validation rules
- `exp` (integer, required): Expiration time in UTC epoch seconds
  - **Calculation**: `iat + 300` (5 minutes)
  - **Constraint**: MUST be <= `iat + 600` (GitHub's 10-minute maximum)
  - **Previous value**: `iat + 600` (10 minutes)
- `iss` (string, required): GitHub App ID
  - **Source**: `$app_id` environment variable
  - **Validation**: Must be numeric (unchanged)

**Encoding**: Base64URL after JSON serialization

**Lifetime**: Valid for 5 minutes after issuance (vs. previous 10 minutes)

---

### 4. Timing Diagnostic Data

**Description**: Timing information logged when authentication fails

**Structure** (logged to stderr):
```text
JWT timing info (UTC epoch seconds):
  Issued at (iat): 1700000000
  Expires at (exp): 1700000300
  Current time: 1700000250
```

**Fields**:
- `iat`: Value from JWT payload at time of generation
- `exp`: Value from JWT payload at time of generation
- `Current time`: Fresh UTC timestamp at time of error

**Purpose**: Enable users to diagnose clock skew vs. expiration issues

**Lifetime**: Logged output only (not stored)

---

## State Transitions

### JWT Generation Flow (Modified)

```
[Start]
   |
   v
[Retrieve UTC Time] ---(fail)---> [Exit with Error: "Failed to retrieve system time"]
   |
   (success)
   v
[Validate Time Range] ---(out of range)---> [Exit with Error: "System clock appears incorrect"]
   |
   (valid)
   v
[Calculate iat = current_time]
   |
   v
[Calculate exp = iat + 300]  // *** CHANGED from iat + 600
   |
   v
[Build JWT Payload with iat, exp, iss]
   |
   v
[Sign JWT with Private Key]
   |
   v
[Return Signed JWT]
   |
   v
[Call GitHub API]
   |
   +---(401)---> [Log Diagnostic Timing Info] ---> [Exit with Error]
   |
   (2xx)
   v
[Export Installation Token]
   |
   v
[Success]
```

---

## Relationships

### Temporal Dependencies

```
UTC Timestamp (current_time)
    |
    |--(direct copy)--> JWT Payload.iat
    |
    |--(+300 seconds)--> JWT Payload.exp
    |
    |--(validation)---> Extreme Clock Error Detection

JWT Payload
    |
    |--(on 401 error)--> Diagnostic Timing Log
```

### Validation Dependencies

```
System `date -u` Command
    |
    v
UTC Timestamp Validation
    |
    +--(check: non-empty)
    +--(check: numeric)
    +--(check: >= 2020 epoch)
    +--(check: <= 2100 epoch)
    |
    v
JWT Payload Generation
```

---

## Constraints

### Timing Constraints

| Constraint | Rule | Enforcement |
|------------|------|-------------|
| JWT exp duration | `exp - iat == 300` (5 minutes) | Set during payload generation |
| GitHub max duration | `exp - iat <= 600` (10 minutes) | Validated by calculation (300 < 600) |
| Clock validity range | `1577836800 <= timestamp <= 4102444800` | Validated before JWT generation |
| UTC requirement | All timestamps in UTC (not local time) | Use `date -u` exclusively |

### Data Integrity

| Field | Constraint | Validation Method |
|-------|-----------|------------------|
| iat | Positive integer, UTC epoch seconds | Regex `^[0-9]+$`, range check |
| exp | Positive integer, UTC epoch seconds, > iat | Calculation ensures correctness |
| timestamp retrieval | Non-empty, numeric output from `date -u` | Explicit check before use |

---

## Security Considerations

### No Sensitive Data in Logs

**Rule**: JWT payload fields (iat, exp) are logged ONLY in UTC epoch seconds. The full JWT token, signature, or private key are NEVER logged.

**Rationale**: Epoch timestamps are not sensitive (they don't reveal credentials). Full JWT tokens could be replayed if logged.

**Implementation**: Error logging includes only numeric epoch values, not encoded JWT strings.

---

## Changes from Previous Implementation

| Aspect | Previous | New | Reason |
|--------|----------|-----|--------|
| `exp` calculation | `iat + 600` (10 min) | `iat + 300` (5 min) | Provide 5-minute safety margin for clock skew |
| UTC enforcement | Implicit (may use local time) | Explicit (`date -u`) | Prevent timezone-related errors |
| Time validation | None | Range check (2020-2100) | Detect extreme clock errors early |
| Error diagnostics | Generic 401 error | Log iat/exp/current_time | Enable clock skew troubleshooting |

---

## Testing Data Scenarios

### Valid Scenarios

1. **Normal operation** (current_time = 1700000000):
   - iat = 1700000000
   - exp = 1700000300
   - Result: Success

2. **Clock 3 minutes ahead of GitHub** (local = 1700000180, GitHub = 1700000000):
   - iat = 1700000180
   - exp = 1700000480 (480 seconds from GitHub's perspective)
   - Result: Success (480 < 600, within tolerance)

3. **Clock 3 minutes behind GitHub** (local = 1699999820, GitHub = 1700000000):
   - iat = 1699999820
   - exp = 1700000120
   - Result: Success (already 120 seconds into validity period from GitHub's view)

### Invalid Scenarios

1. **Extreme future clock** (current_time = 5000000000):
   - Validation fails: > MAX_VALID_EPOCH (4102444800)
   - Result: Exit with error before JWT generation

2. **Extreme past clock** (current_time = 1000000000):
   - Validation fails: < MIN_VALID_EPOCH (1577836800)
   - Result: Exit with error before JWT generation

3. **Time retrieval failure** (date command fails):
   - Validation fails: empty or non-numeric output
   - Result: Exit with error "Failed to retrieve system time"
