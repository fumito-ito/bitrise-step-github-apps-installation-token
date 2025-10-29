# Quickstart Guide: YAML Permissions Format

**Feature**: 002-yaml-permissions-format
**Date**: 2025-10-29
**Audience**: Bitrise workflow developers using the GitHub Apps Installation Token step

## Overview

The GitHub Apps Installation Token step now supports **YAML hash format** for the `permissions` parameter, making your workflow configurations more readable and easier to maintain.

**What's New**:
- Specify permissions using native YAML key-value syntax (recommended)
- Existing JSON string format continues to work (backward compatible)
- Clearer error messages when permissions format is invalid

**Migration Status**: Optional - you can migrate at your own pace, or keep using JSON strings indefinitely.

---

## Quick Comparison

### Before (JSON String Format)

```yaml
- github-apps-installation-token:
    inputs:
    - app_id: $GITHUB_APP_ID
    - installation_id: $GITHUB_INSTALLATION_ID
    - private_pem: $GITHUB_APP_PRIVATE_PEM
    - permissions: '{"contents":"read","issues":"write","pull_requests":"write"}'
```

### After (YAML Hash Format)

```yaml
- github-apps-installation-token:
    inputs:
    - app_id: $GITHUB_APP_ID
    - installation_id: $GITHUB_INSTALLATION_ID
    - private_pem: $GITHUB_APP_PRIVATE_PEM
    - permissions:
        contents: read
        issues: write
        pull_requests: write
```

**Benefits**:
- ✅ More readable (no escaped quotes)
- ✅ Easier to edit (add/remove permissions without JSON syntax errors)
- ✅ Consistent with YAML workflow conventions
- ✅ Less error-prone (no quote escaping issues)

---

## Migration Guide

### Step 1: Identify Your Current Configuration

Find the `github-apps-installation-token` step in your `bitrise.yml` and check the `permissions` parameter:

```yaml
# Example 1: JSON string with single permission
- permissions: '{"contents":"read"}'

# Example 2: JSON string with multiple permissions
- permissions: '{"contents":"read","issues":"write","metadata":"read"}'

# Example 3: No permissions specified (all app permissions)
# (no permissions parameter)
```

### Step 2: Convert to YAML Hash Format

**Conversion Pattern**:

```yaml
# Original JSON string
- permissions: '{"permission_name":"access_level","permission_name":"access_level"}'

# Converted YAML hash
- permissions:
    permission_name: access_level
    permission_name: access_level
```

**Examples**:

| JSON String Format | YAML Hash Format |
|-------------------|------------------|
| `'{"contents":"read"}'` | `permissions:`<br>`  contents: read` |
| `'{"issues":"write"}'` | `permissions:`<br>`  issues: write` |
| `'{"contents":"read","issues":"write"}'` | `permissions:`<br>`  contents: read`<br>`  issues: write` |
| `'{"contents":"read","metadata":"read","pull_requests":"write"}'` | `permissions:`<br>`  contents: read`<br>`  metadata: read`<br>`  pull_requests: write` |

### Step 3: Update Your bitrise.yml

**Original Configuration**:

```yaml
workflows:
  deploy:
    steps:
    - github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
        - permissions: '{"contents":"read","deployments":"write","statuses":"write"}'
    - script:
        inputs:
        - content: |
            #!/bin/bash
            echo "Token: $GITHUB_APPS_INSTALLATION_TOKEN"
```

**Migrated Configuration**:

```yaml
workflows:
  deploy:
    steps:
    - github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
        - permissions:
            contents: read
            deployments: write
            statuses: write
    - script:
        inputs:
        - content: |
            #!/bin/bash
            echo "Token: $GITHUB_APPS_INSTALLATION_TOKEN"
```

### Step 4: Test Your Workflow

Run your workflow with the new YAML hash format:

```bash
bitrise run deploy
```

**Expected Behavior**:
- Workflow runs successfully
- Token is generated with the specified permissions
- No changes to token functionality or output

**If You See Errors**:
- Check YAML indentation (must use spaces, not tabs)
- Ensure permission names and access levels match GitHub's format
- Verify no trailing spaces or special characters

---

## Common Migration Scenarios

### Scenario 1: Read-Only Permissions

**Before**:

```yaml
- permissions: '{"contents":"read","metadata":"read"}'
```

**After**:

```yaml
- permissions:
    contents: read
    metadata: read
```

### Scenario 2: Mixed Read/Write Permissions

**Before**:

```yaml
- permissions: '{"contents":"read","issues":"write","pull_requests":"write","checks":"write"}'
```

**After**:

```yaml
- permissions:
    contents: read
    issues: write
    pull_requests: write
    checks: write
```

### Scenario 3: Single Permission

**Before**:

```yaml
- permissions: '{"checks":"write"}'
```

**After**:

```yaml
- permissions:
    checks: write
```

### Scenario 4: All App Permissions (No Restrictions)

**Before**:

```yaml
# No permissions parameter specified
- github-apps-installation-token:
    inputs:
    - app_id: $GITHUB_APP_ID
    - installation_id: $GITHUB_INSTALLATION_ID
    - private_pem: $GITHUB_APP_PRIVATE_PEM
```

**After**:

```yaml
# Still omit the permissions parameter (no migration needed)
- github-apps-installation-token:
    inputs:
    - app_id: $GITHUB_APP_ID
    - installation_id: $GITHUB_INSTALLATION_ID
    - private_pem: $GITHUB_APP_PRIVATE_PEM
```

**Note**: If you want all app permissions, continue to omit the `permissions` parameter entirely.

---

## Backward Compatibility

### Do I Need to Migrate?

**No, migration is optional.** The JSON string format continues to work indefinitely.

**JSON String Format (Legacy)**:
- ✅ Still supported
- ✅ Same behavior as before
- ✅ No deprecation timeline
- ✅ No breaking changes

**When to Migrate**:
- When creating new workflows (use YAML hash format from the start)
- When updating existing workflows (take the opportunity to migrate)
- When readability is important (YAML hash is easier to read)

**When NOT to Migrate**:
- If your workflows are stable and working (no need to change)
- If you prefer JSON string format (personal preference is fine)
- If you're using the step in a template that might run on older versions

### Can I Mix Formats?

**Yes, you can use different formats in different workflows:**

```yaml
workflows:
  # Workflow 1: YAML hash format
  build:
    steps:
    - github-apps-installation-token:
        inputs:
        - permissions:
            contents: read

  # Workflow 2: JSON string format
  test:
    steps:
    - github-apps-installation-token:
        inputs:
        - permissions: '{"contents":"read"}'
```

**Both workflows generate identical tokens** - the format choice is purely for readability.

---

## Common Permissions Reference

### Repository Permissions

| Permission | Access Levels | Use Case |
|------------|---------------|----------|
| `contents` | `read`, `write` | Read/write repository files, commits, branches |
| `metadata` | `read` | Read repository metadata (always read-only) |
| `issues` | `read`, `write` | Read/create/update issues and comments |
| `pull_requests` | `read`, `write` | Read/create/update pull requests and reviews |
| `checks` | `read`, `write` | Read/create check runs (CI/CD status) |
| `statuses` | `read`, `write` | Read/create commit statuses |
| `deployments` | `read`, `write` | Read/create deployments and statuses |
| `actions` | `read`, `write` | Read/trigger GitHub Actions workflows |
| `packages` | `read`, `write` | Read/publish GitHub Packages |

**YAML Hash Example** (common CI/CD permissions):

```yaml
- permissions:
    contents: read
    checks: write
    statuses: write
```

**JSON String Example** (same permissions):

```yaml
- permissions: '{"contents":"read","checks":"write","statuses":"write"}'
```

---

## Troubleshooting

### Error: "Invalid permissions format"

**New Error Message**:

```
Error: Invalid permissions format
Expected: YAML hash (e.g., contents: read) or valid JSON string
Received: <your_value>
```

**Common Causes**:

1. **YAML Indentation Error**:

   ```yaml
   # ❌ Wrong: Missing indentation
   - permissions:
   contents: read

   # ✅ Correct: Proper indentation (2 spaces)
   - permissions:
       contents: read
   ```

2. **JSON String Quote Error**:

   ```yaml
   # ❌ Wrong: Missing quotes around JSON string
   - permissions: {"contents":"read"}

   # ✅ Correct: JSON string must be quoted
   - permissions: '{"contents":"read"}'
   ```

3. **Mixed Format Error**:

   ```yaml
   # ❌ Wrong: Mixing YAML hash and JSON string
   - permissions: '{"contents":"read"}'
       issues: write

   # ✅ Correct: Use one format consistently
   - permissions:
       contents: read
       issues: write
   ```

### YAML Hash Not Working

**Check 1: Indentation**

YAML is indentation-sensitive. Ensure proper spacing:

```yaml
# ✅ Correct
- github-apps-installation-token:
    inputs:
    - app_id: $GITHUB_APP_ID
    - permissions:
        contents: read
        issues: write

# ❌ Wrong: Tab characters instead of spaces
- github-apps-installation-token:
	inputs:
	- permissions:
		contents: read
```

**Solution**: Use 2 or 4 spaces for indentation, NOT tabs.

**Check 2: Colons and Spacing**

```yaml
# ✅ Correct: Space after colon
- permissions:
    contents: read

# ❌ Wrong: No space after colon
- permissions:
    contents:read

# ❌ Wrong: Colon missing
- permissions:
    contents read
```

**Check 3: Access Level Values**

```yaml
# ✅ Correct: "read" or "write"
- permissions:
    contents: read
    issues: write

# ❌ Wrong: Invalid access level
- permissions:
    contents: readonly  # Should be "read"
    issues: readwrite   # Should be "read" or "write"
```

### JSON String Format Still Failing

**Common Issues**:

```yaml
# ❌ Wrong: Double quotes around JSON string
- permissions: "{\"contents\":\"read\"}"

# ✅ Correct: Single quotes around JSON string
- permissions: '{"contents":"read"}'

# ❌ Wrong: Missing quotes
- permissions: {"contents":"read"}

# ✅ Correct: Quoted JSON string
- permissions: '{"contents":"read"}'
```

---

## Examples by Use Case

### CI/CD Build Check

**Use Case**: Report build status to GitHub pull requests

**YAML Hash Format**:

```yaml
workflows:
  ci:
    steps:
    - github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
        - permissions:
            checks: write
            statuses: write
    - script:
        title: "Report build status"
        inputs:
        - content: |
            #!/bin/bash
            curl -X POST \
              -H "Authorization: Bearer $GITHUB_APPS_INSTALLATION_TOKEN" \
              -H "Accept: application/vnd.github+json" \
              -d '{"name":"build","status":"completed","conclusion":"success"}' \
              "https://api.github.com/repos/$REPO/check-runs"
```

### Deployment Workflow

**Use Case**: Create deployment and update status

**YAML Hash Format**:

```yaml
workflows:
  deploy:
    steps:
    - github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
        - permissions:
            deployments: write
            statuses: write
    - script:
        title: "Create deployment"
        inputs:
        - content: |
            #!/bin/bash
            curl -X POST \
              -H "Authorization: Bearer $GITHUB_APPS_INSTALLATION_TOKEN" \
              -d '{"ref":"main","environment":"production"}' \
              "https://api.github.com/repos/$REPO/deployments"
```

### Issue Management

**Use Case**: Create or update GitHub issues from CI

**YAML Hash Format**:

```yaml
workflows:
  issue-report:
    steps:
    - github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
        - permissions:
            issues: write
    - script:
        title: "Create issue"
        inputs:
        - content: |
            #!/bin/bash
            curl -X POST \
              -H "Authorization: Bearer $GITHUB_APPS_INSTALLATION_TOKEN" \
              -d '{"title":"Build failed","body":"Details..."}' \
              "https://api.github.com/repos/$REPO/issues"
```

### Read-Only Access

**Use Case**: Fetch repository contents without write access

**YAML Hash Format**:

```yaml
workflows:
  fetch-data:
    steps:
    - github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
        - permissions:
            contents: read
            metadata: read
    - script:
        title: "Fetch repository files"
        inputs:
        - content: |
            #!/bin/bash
            curl -H "Authorization: Bearer $GITHUB_APPS_INSTALLATION_TOKEN" \
              "https://api.github.com/repos/$REPO/contents/README.md"
```

---

## Migration Checklist

- [ ] Identify all workflows using `github-apps-installation-token` step
- [ ] For each workflow with `permissions` parameter:
  - [ ] Extract permission names and access levels from JSON string
  - [ ] Convert to YAML hash format (indentation, colons, spacing)
  - [ ] Update bitrise.yml with new format
  - [ ] Test workflow locally with `bitrise run <workflow>`
  - [ ] Verify token has correct permissions
- [ ] Commit changes to version control
- [ ] Test in CI environment
- [ ] Monitor first few builds for any issues

---

## FAQ

### Q: Will migrating change my token's permissions?

**A:** No. Both YAML hash and JSON string formats produce **identical tokens** with the same permissions. The format change is purely for readability.

### Q: Do I need to update my step version?

**A:** If you're using a version that includes this feature (check the step's changelog), you can use YAML hash format immediately. Older versions will continue to work with JSON string format.

### Q: Can I use environment variables in permissions?

**A:** No. Permission names and access levels must be literal strings. This is enforced by setting `is_expand: false` in the step configuration to prevent unintended variable expansion.

```yaml
# ❌ Not supported: Environment variables
- permissions:
    $PERMISSION_NAME: read

# ✅ Supported: Literal permission names
- permissions:
    contents: read
```

### Q: What happens if I specify an invalid permission name?

**A:** The step validates JSON syntax but defers permission name validation to the GitHub API. If you specify an invalid permission name, you'll get a clear error from GitHub explaining which permission is invalid.

### Q: How do I know which permissions my app has?

**A:** Check your GitHub App settings page:
1. Go to Settings → Developer settings → GitHub Apps
2. Select your app
3. Scroll to "Permissions" section
4. Only request permissions your app has been configured with

---

## Next Steps

1. **Try It Out**: Update one workflow to use YAML hash format
2. **Test Locally**: Run `bitrise run <workflow>` to verify
3. **Migrate Gradually**: Update remaining workflows at your own pace
4. **Share Feedback**: Report issues or suggestions to the step maintainers

**Documentation**:
- [GitHub Apps Permissions Reference](https://docs.github.com/en/rest/apps/apps#create-an-installation-access-token-for-an-app)
- [Bitrise YAML Reference](https://devcenter.bitrise.io/en/references/bitrise-yml-reference.html)

---

**Happy Building! 🚀**
