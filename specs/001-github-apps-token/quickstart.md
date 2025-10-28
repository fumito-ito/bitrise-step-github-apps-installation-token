# Quickstart Guide: GitHub Apps Installation Token Generator

**Feature**: 001-github-apps-token
**Date**: 2025-10-28

## Overview

This guide walks you through setting up and testing the GitHub Apps Installation Token Bitrise step locally, then integrating it into your Bitrise workflows.

---

## Prerequisites

### 1. GitHub App Setup

You need a GitHub App with the following:

**Required**:
- GitHub App created on your account or organization
- App ID (find in App settings → About → App ID)
- Private key downloaded (.pem file)
- App installed on your account/organization
- Installation ID (find in installation URL or via API)

**How to create a GitHub App** (if you don't have one):

1. Go to GitHub Settings → Developer settings → GitHub Apps → New GitHub App
2. Fill in basic information (name, homepage URL)
3. Set permissions (e.g., Contents: Read, Issues: Write)
4. Click "Create GitHub App"
5. Note the **App ID** (you'll need this)
6. Scroll to "Private keys" → "Generate a private key"
7. Download the `.pem` file (you'll need this)
8. Install the app: "Install App" → Select account/org → Select repositories
9. Note the **Installation ID** from the URL: `https://github.com/settings/installations/<INSTALLATION_ID>`

### 2. Local Development Tools

**Required tools** (should be pre-installed on most systems):
- `openssl` 1.0.2+
- `curl` 7.x+
- `jq` 1.5+
- `bash` 4.x+
- Bitrise CLI ([installation guide](https://github.com/bitrise-io/bitrise#install-and-setup))

**Verify tools**:
```bash
openssl version    # Should show 1.0.2 or higher
curl --version     # Should show 7.x or higher
jq --version       # Should show 1.5 or higher
bash --version     # Should show 4.x or higher
bitrise --version  # Should show installed version
```

**Install Bitrise CLI** (if not installed):
```bash
# macOS
brew install bitrise

# Linux
curl -fL https://github.com/bitrise-io/bitrise/releases/download/1.x.x/bitrise-$(uname -s)-$(uname -m) > /usr/local/bin/bitrise
chmod +x /usr/local/bin/bitrise
```

---

## Local Testing

### Step 1: Clone the Repository

```bash
git clone https://github.com/Nikkei/bitrise-step-github-apps-installation-token.git
cd bitrise-step-github-apps-installation-token
```

### Step 2: Create Secrets File

Create `.bitrise.secrets.yml` in the repository root (this file is git-ignored):

```yaml
envs:
# GitHub App credentials
- GITHUB_APP_ID: "123456"  # Your GitHub App ID
- GITHUB_INSTALLATION_ID: "789012"  # Your installation ID
- GITHUB_APP_PRIVATE_PEM: |
    -----BEGIN RSA PRIVATE KEY-----
    MIIEpAIBAAKCAQEA...
    (paste your full private key here)
    ...
    -----END RSA PRIVATE KEY-----
```

**Security Note**: Never commit `.bitrise.secrets.yml` to git. It's already in `.gitignore`.

### Step 3: Run Test Workflow

```bash
bitrise run test
```

**Expected output**:
```
+------------------------------------------------------------------------------+
| (0) github-apps-installation-token@path                                      |
+------------------------------------------------------------------------------+
| id: github-apps-installation-token                                           |
| version: path                                                                |
| collection: https://github.com/bitrise-io/bitrise-steplib.git              |
| toolkit: bash                                                                |
| time: 2025-10-28T10:30:00Z                                                  |
+------------------------------------------------------------------------------+
|                                                                              |
| Validating inputs...                                                         |
| ✓ App ID: 123456                                                            |
| ✓ Installation ID: 789012                                                   |
| ✓ Private PEM key: valid format                                             |
|                                                                              |
| Generating JWT...                                                            |
| ✓ JWT generated (expires in 10 minutes)                                     |
|                                                                              |
| Requesting installation token from GitHub API...                            |
| ✓ Token generated successfully                                              |
| ✓ Token expires at: 2025-10-28T11:30:00Z                                   |
|                                                                              |
| Exporting token to environment...                                           |
| ✓ Token exported to GITHUB_APPS_INSTALLATION_TOKEN                          |
|                                                                              |
| ✓ Success: GitHub Apps Installation Token generated                         |
+------------------------------------------------------------------------------+
| ✓ | github-apps-installation-token@path (exit code: 0)                  | 3 sec|
+------------------------------------------------------------------------------+
```

### Step 4: Verify Token Works

Add a verification step to `bitrise.yml` (temporary, for testing):

```yaml
workflows:
  test:
    steps:
    - path::./:
        title: Generate GitHub Apps Token
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
    - script:
        title: Verify Token
        inputs:
        - content: |
            #!/bin/bash
            set -e
            echo "Token (first 20 chars): ${GITHUB_APPS_INSTALLATION_TOKEN:0:20}..."

            # Test token with GitHub API
            response=$(curl -s -w "\n%{http_code}" \
              -H "Authorization: Bearer $GITHUB_APPS_INSTALLATION_TOKEN" \
              -H "Accept: application/vnd.github+json" \
              "https://api.github.com/installation/repositories")

            http_code=$(echo "$response" | tail -n1)

            if [ "$http_code" = "200" ]; then
              echo "✓ Token is valid and working!"
              repo_count=$(echo "$response" | sed '$d' | jq '.total_count')
              echo "  Accessible repositories: $repo_count"
            else
              echo "✗ Token validation failed (HTTP $http_code)"
              exit 1
            fi
```

Run again:
```bash
bitrise run test
```

---

## Testing Custom Permissions

Create a test workflow for custom permissions:

```yaml
workflows:
  test-permissions:
    steps:
    - path::./:
        title: Generate Token with Custom Permissions
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
        - permissions: '{"contents": "read", "issues": "write"}'
    - script:
        title: Verify Permissions
        inputs:
        - content: |
            #!/bin/bash
            set -e
            # Verify token has only requested permissions
            curl -s \
              -H "Authorization: Bearer $GITHUB_APPS_INSTALLATION_TOKEN" \
              -H "Accept: application/vnd.github+json" \
              "https://api.github.com/installation" \
              | jq '.permissions'
```

Run:
```bash
bitrise run test-permissions
```

---

## Testing Error Handling

### Test: Missing App ID

```yaml
workflows:
  test-missing-app-id:
    steps:
    - path::./:
        title: Test Missing App ID
        is_skippable: true  # Allow workflow to continue after failure
        inputs:
        - app_id: ""  # Empty app_id
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
```

Expected: Step fails with "Error: App ID is required"

### Test: Invalid PEM Format

```yaml
workflows:
  test-invalid-pem:
    steps:
    - path::./:
        title: Test Invalid PEM
        is_skippable: true
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: "not a valid PEM key"
```

Expected: Step fails with "Error: Invalid PEM format"

### Test: Invalid Installation ID

```yaml
workflows:
  test-invalid-installation:
    steps:
    - path::./:
        title: Test Invalid Installation ID
        is_skippable: true
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: "99999999"  # Non-existent installation
        - private_pem: $GITHUB_APP_PRIVATE_PEM
```

Expected: Step fails with "Error: Installation ID not found"

---

## Integrating into Bitrise Workflows

### Option 1: Local Step Reference (Development)

While developing, use local path reference:

```yaml
workflows:
  deploy:
    steps:
    - path::/path/to/bitrise-step-github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
```

### Option 2: Git Reference (Testing)

Push to your fork and reference via Git:

```yaml
workflows:
  deploy:
    steps:
    - git::https://github.com/YOUR_ORG/bitrise-step-github-apps-installation-token.git@main:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
```

### Option 3: Step Library (Production)

After publishing to Bitrise Step Library:

```yaml
workflows:
  deploy:
    steps:
    - github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
```

---

## Common Use Cases

### Use Case 1: Clone Private Repository

```yaml
workflows:
  build:
    steps:
    - github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
    - script:
        inputs:
        - content: |
            #!/bin/bash
            git clone https://x-access-token:${GITHUB_APPS_INSTALLATION_TOKEN}@github.com/org/private-repo.git
```

### Use Case 2: Create GitHub Release

```yaml
workflows:
  release:
    steps:
    - github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
        - permissions: '{"contents": "write"}'
    - script:
        inputs:
        - content: |
            #!/bin/bash
            curl -X POST \
              -H "Authorization: Bearer $GITHUB_APPS_INSTALLATION_TOKEN" \
              -H "Accept: application/vnd.github+json" \
              "https://api.github.com/repos/owner/repo/releases" \
              -d '{"tag_name":"v1.0.0","name":"Release v1.0.0"}'
```

### Use Case 3: Update Pull Request Status

```yaml
workflows:
  test:
    steps:
    - github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
        - permissions: '{"checks": "write"}'
    - script:
        inputs:
        - content: |
            #!/bin/bash
            # Run tests...

            # Update check status
            curl -X POST \
              -H "Authorization: Bearer $GITHUB_APPS_INSTALLATION_TOKEN" \
              -H "Accept: application/vnd.github+json" \
              "https://api.github.com/repos/owner/repo/check-runs" \
              -d '{"name":"Tests","status":"completed","conclusion":"success"}'
```

---

## Storing Secrets in Bitrise

### Step 1: Add Secrets to Bitrise App

1. Go to your Bitrise app → Workflow → Secrets
2. Add three secrets:
   - `GITHUB_APP_ID`: Your GitHub App ID (can be non-secret)
   - `GITHUB_INSTALLATION_ID`: Your installation ID (can be non-secret)
   - `GITHUB_APP_PRIVATE_PEM`: Your private PEM key (**MUST be secret**)

**Important**: Mark `GITHUB_APP_PRIVATE_PEM` as "Protected" and "Expose for Pull Requests" = No

### Step 2: Reference in Workflow

```yaml
workflows:
  deploy:
    steps:
    - github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID  # References secret from Bitrise
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM  # Securely passed
```

---

## Troubleshooting

### Error: "App ID is required"

**Cause**: `app_id` input is empty or not set

**Solution**:
- Check `.bitrise.secrets.yml` has `GITHUB_APP_ID` defined
- Verify the environment variable is being passed to the step
- Ensure no quotes or extra whitespace around the value

### Error: "Invalid PEM format"

**Cause**: Private key doesn't have proper BEGIN/END markers

**Solution**:
- Verify you copied the entire `.pem` file content including:
  ```
  -----BEGIN RSA PRIVATE KEY-----
  ...
  -----END RSA PRIVATE KEY-----
  ```
- Check for extra characters or truncation
- Ensure line breaks are preserved (use `|` in YAML for multiline)

### Error: "GitHub authentication failed"

**Cause**: App ID or private key is incorrect

**Solution**:
- Verify App ID matches your GitHub App settings
- Ensure you're using the private key for the correct app
- Check the key hasn't been revoked or regenerated

### Error: "Installation ID not found"

**Cause**: Installation ID doesn't exist or app isn't installed

**Solution**:
- Verify installation ID from GitHub:
  - Go to GitHub → Settings → Installations → Your App
  - Check URL: `https://github.com/settings/installations/<ID>`
- Ensure the app is installed on the account/org you're using

### Error: "GitHub API rejected permissions"

**Cause**: Requested permissions not configured for the app

**Solution**:
- Go to GitHub App settings → Permissions
- Grant the requested permissions
- Save changes
- May need to re-approve installation in organization

### Error: "Failed to reach GitHub API"

**Cause**: Network connectivity issue

**Solution**:
- Check internet connection
- Verify Bitrise stack can reach api.github.com
- Check for firewall or proxy issues

### Token Expires Too Quickly

**Cause**: Installation tokens have 1-hour lifetime (GitHub limitation)

**Solution**:
- Generate token at the start of each workflow that needs it
- For long-running workflows, generate a new token after 55 minutes
- Cannot be extended - this is a GitHub API limitation

---

## Next Steps

After verifying local testing works:

1. **Commit changes** to your feature branch
2. **Create pull request** with implementation
3. **Run CI/CD tests** on Bitrise
4. **Audit step** with `bitrise run audit-this-step`
5. **Publish to Step Library** (see [Bitrise docs](https://github.com/bitrise-io/bitrise#share-your-step))

---

## Additional Resources

- [GitHub Apps Documentation](https://docs.github.com/en/apps)
- [Bitrise Step Development Guide](https://github.com/bitrise-io/bitrise/blob/master/_docs/step-development-guideline.md)
- [Feature Specification](spec.md)
- [GitHub API Contract](contracts/github-api-contract.md)
- [Step I/O Contract](contracts/step-io-contract.md)
