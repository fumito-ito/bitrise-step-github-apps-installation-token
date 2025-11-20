# Quickstart: Testing JWT Clock Skew Fix

**Feature**: 001-fix-jwt-clock-skew
**Date**: 2025-11-19

## Purpose

This guide helps developers and QA test the JWT clock skew fix in different scenarios. It covers normal operation, simulated clock skew, and error conditions.

## Prerequisites

- Bitrise CLI installed (`bitrise --version`)
- GitHub App credentials:
  - App ID
  - Installation ID
  - Private key (PEM format)
- Access to `.bitrise.secrets.yml` or environment variables

## Quick Test: Normal Operation

### 1. Set up credentials

Create or edit `.bitrise.secrets.yml` (git-ignored):

```yaml
envs:
- APP_ID: "YOUR_APP_ID"
- INSTALLATION_ID: "YOUR_INSTALLATION_ID"
- PRIVATE_PEM: |
    -----BEGIN RSA PRIVATE KEY-----
    YOUR_PRIVATE_KEY_CONTENT_HERE
    -----END RSA PRIVATE KEY-----
```

### 2. Run the step locally

```bash
bitrise run test
```

**Expected Output**:
```
✓ GitHub Apps Installation Token generated successfully
Token expires in: 5 minutes (300 seconds)
```

**Verification**:
```bash
# Check that token was exported
echo $GITHUB_APPS_INSTALLATION_TOKEN

# Verify it's usable
curl -H "Authorization: Bearer $GITHUB_APPS_INSTALLATION_TOKEN" \
     https://api.github.com/installation/repositories
```

---

## Test Scenario 1: Simulated Clock Skew (Future)

### Objective
Verify that the 5-minute expiration provides tolerance for clocks ahead of GitHub servers.

### Setup

Temporarily adjust system clock **5 minutes into the future**:

```bash
# macOS
sudo systemsetup -setdate MM:DD:YYYY
sudo systemsetup -settime HH:MM:SS

# Linux
sudo date -s "$(date -d '+5 minutes')"
```

**⚠️ Warning**: Adjusting system clock may affect other processes. Test in isolated environment (VM/container).

### Test

```bash
bitrise run test
```

**Expected Result**: ✅ Success
- JWT generated with iat = future time
- exp = iat + 300
- GitHub sees JWT as recently issued (within tolerance)

### Cleanup

Reset system clock to actual time:

```bash
# macOS
sudo systemsetup -setusingnetworktime on

# Linux
sudo ntpdate -s time.nist.gov
# or
sudo timedatectl set-ntp true
```

---

## Test Scenario 2: Simulated Clock Skew (Past)

### Objective
Verify that tokens work when local clock is behind GitHub servers.

### Setup

Adjust system clock **3 minutes into the past**:

```bash
# Linux
sudo date -s "$(date -d '-3 minutes')"
```

### Test

```bash
bitrise run test
```

**Expected Result**: ✅ Success
- JWT issued with iat in the past (from GitHub's perspective)
- GitHub accepts it because it's still within validity window

### Cleanup

Reset clock (same as Scenario 1).

---

## Test Scenario 3: Extreme Clock Error Detection

### Objective
Verify that extreme clock errors (>1 hour) are detected before JWT generation.

### Setup

Set system clock to an absurd value (e.g., year 2000):

```bash
# Linux
sudo date -s "2000-01-01 12:00:00"
```

### Test

```bash
bitrise run test
```

**Expected Result**: ❌ Failure with clear error
```
Error: System clock appears to be incorrect (timestamp: 946728000)
Please verify system time is set correctly and try again.
```

**Exit code**: 1 (validation error)

### Cleanup

Reset clock to actual time.

---

## Test Scenario 4: UTC vs Local Time Verification

### Objective
Confirm that all timestamps use UTC, not local timezone.

### Setup

Set a non-UTC timezone:

```bash
export TZ="Asia/Tokyo"  # UTC+9
```

### Test

Run step and capture JWT:

```bash
bitrise run test 2>&1 | tee output.log
```

### Verification

Check that iat in JWT payload matches UTC time, not Tokyo time:

```bash
# Get current UTC epoch
date -u +%s

# Decode JWT payload (middle section between dots)
# Should show iat approximately equal to UTC time above
```

**Expected**: iat matches `date -u +%s`, NOT `date +%s` (local time).

---

## Test Scenario 5: Time Retrieval Failure

### Objective
Verify error handling when `date` command is unavailable or fails.

### Setup (Requires Docker/Container)

Create a minimal container without `date` command:

```dockerfile
FROM busybox:latest
RUN rm /bin/date
COPY step.sh /step.sh
```

### Test

```bash
docker run --rm test-container /step.sh
```

**Expected Result**: ❌ Failure
```
Error: Failed to execute 'date -u +%s' command
System time utilities may be misconfigured
```

**Exit code**: 1

---

## Test Scenario 6: Diagnostic Logging on 401 Error

### Objective
Verify that timing diagnostics are logged when GitHub API returns 401.

### Setup

Use **invalid credentials** (e.g., wrong App ID):

```yaml
envs:
- APP_ID: "999999999"  # Invalid App ID
- INSTALLATION_ID: "YOUR_VALID_INSTALLATION_ID"
- PRIVATE_PEM: |
    YOUR_VALID_PRIVATE_KEY
```

### Test

```bash
bitrise run test 2>&1 | tee error.log
```

**Expected Output** (in stderr):
```
Error: GitHub API authentication failed (401)
JWT timing info (UTC epoch seconds):
  Issued at (iat): 1700000000
  Expires at (exp): 1700000300
  Current time: 1700000015
Possible causes: clock skew, expired JWT, or invalid credentials
```

**Verification**:
- iat and exp are reasonable UTC epochs
- exp - iat == 300 (5 minutes)
- Current time is close to iat (within seconds)
- No JWT token string is logged (security requirement)

---

## Performance Benchmark

### Objective
Verify that token generation completes within 5 seconds.

### Test

```bash
time bitrise run test
```

**Expected**: Total time < 5 seconds (network latency dependent)

**Breakdown**:
- Time retrieval: <10ms
- JWT generation: <50ms
- GitHub API call: 100-2000ms (varies by network)

---

## Regression Test: Existing Functionality

### Objective
Confirm that the clock skew fix doesn't break existing features.

### Tests

1. **Custom permissions** (if applicable):
   ```yaml
   envs:
   - permissions: |
       contents: read
       issues: write
   ```
   Expected: Token generated with restricted permissions

2. **Token expiration**:
   Wait 5 minutes and 30 seconds, then try to use token.
   Expected: GitHub returns 401 (token expired)

3. **Multiple invocations**:
   Run step 3 times in succession.
   Expected: Each generates a new valid token

---

## Troubleshooting Common Issues

### Issue: "Failed to retrieve system time"

**Cause**: `date` command not available or system clock not readable

**Solution**:
1. Verify `date` command exists: `which date`
2. Check permissions: `ls -l /bin/date`
3. Test manually: `date -u +%s`

### Issue: "System clock appears to be incorrect"

**Cause**: System clock is set to a date before 2020 or after 2100

**Solution**:
1. Check current time: `date`
2. Sync with network time:
   - macOS: `sudo systemsetup -setusingnetworktime on`
   - Linux: `sudo timedatectl set-ntp true`

### Issue: 401 errors despite correct credentials

**Cause**: Possible clock skew exceeding tolerance

**Solution**:
1. Check diagnostic output for iat, exp, current_time values
2. Compare iat with actual UTC time: `date -u +%s`
3. If difference > 5 minutes, sync system clock
4. Verify timezone is not interfering: `echo $TZ` (should be empty or UTC)

---

## CI/CD Integration Test

### Objective
Verify the fix works in actual Bitrise workflows.

### Setup

Create a test workflow in `bitrise.yml`:

```yaml
workflows:
  test-clock-skew-fix:
    steps:
    - script:
        title: Display system time
        inputs:
        - content: |
            echo "System UTC time: $(date -u)"
            echo "Epoch: $(date -u +%s)"
    - github-apps-installation-token:
        inputs:
        - app_id: $APP_ID
        - installation_id: $INSTALLATION_ID
        - private_pem: $PRIVATE_PEM
    - script:
        title: Use token
        inputs:
        - content: |
            curl -H "Authorization: Bearer $GITHUB_APPS_INSTALLATION_TOKEN" \
                 https://api.github.com/installation/repositories
```

### Test

Push to Bitrise and trigger workflow.

**Expected**: All steps succeed, token is usable.

---

## Summary Checklist

- [ ] Normal operation: Token generated successfully
- [ ] Clock 5 minutes ahead: Token accepted by GitHub
- [ ] Clock 3 minutes behind: Token accepted by GitHub
- [ ] Extreme clock error: Detected and reported before API call
- [ ] UTC enforcement: Timestamps match `date -u`, not `date`
- [ ] Time retrieval failure: Clear error message
- [ ] 401 diagnostic logging: iat, exp, current_time shown
- [ ] Performance: Completes within 5 seconds
- [ ] Regression: Existing features still work
- [ ] CI/CD integration: Works in actual Bitrise workflows

---

## Next Steps

After testing, proceed to implementation:
- **Phase 2**: Run `/speckit.tasks` to generate task breakdown
- **Implementation**: Modify step.sh according to tasks
- **Final test**: Run all scenarios above to verify fix
