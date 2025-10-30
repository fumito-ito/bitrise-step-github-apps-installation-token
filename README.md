# GitHub Apps Installation Token Generator

Generate GitHub Apps Installation Tokens for authenticating to GitHub APIs in your Bitrise workflows.

This step generates a GitHub Apps Installation Token by accepting your GitHub App ID, Installation ID, and private PEM key. The generated token is exported as `GITHUB_APPS_INSTALLATION_TOKEN` for use in subsequent workflow steps.

## Features

- **Secure Token Generation**: Creates installation tokens using JWT authentication
- **Custom Permissions**: Restrict tokens to specific permissions for least-privilege security
- **Error Handling**: Clear, actionable error messages for all failure scenarios
- **Retry Logic**: Automatic retry for transient API failures (503/429 errors)
- **Security**: Private keys handled securely with restricted file permissions and no logging

## Prerequisites

Before using this step, you need:

1. **GitHub App**: Create a GitHub App in your GitHub organization or account
   - Go to Settings → Developer settings → GitHub Apps → New GitHub App
   - Configure required permissions for your app
   - Generate and download the private key (.pem file)
   - Note the App ID from the "About" section

2. **App Installation**: Install your GitHub App on the target organization/repository
   - Go to your GitHub App settings → Install App
   - Select the organization or account to install on
   - Note the Installation ID from the URL: `https://github.com/settings/installations/{installation_id}`

3. **Bitrise Secrets**: Store credentials as Secret Environment Variables in Bitrise
   - `GITHUB_APP_ID`: Your GitHub App ID
   - `GITHUB_INSTALLATION_ID`: The installation ID
   - `GITHUB_APP_PRIVATE_PEM`: The contents of your .pem file

## Usage

### Basic Usage (All Permissions)

Add this step to your `bitrise.yml`:

```yaml
workflows:
  deploy:
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
            # Use the token in subsequent steps
            curl -H "Authorization: Bearer $GITHUB_APPS_INSTALLATION_TOKEN" \
              https://api.github.com/repos/owner/repo/issues
```

### Custom Permissions (Least-Privilege)

Restrict the token to specific permissions using YAML hash format:

```yaml
workflows:
  build:
    steps:
    - github-apps-installation-token:
        inputs:
        - app_id: $GITHUB_APP_ID
        - installation_id: $GITHUB_INSTALLATION_ID
        - private_pem: $GITHUB_APP_PRIVATE_PEM
        - permissions:
            contents: read
            checks: write
    - script:
        inputs:
        - content: |
            #!/bin/bash
            # Token has only contents:read and checks:write permissions
            echo "Token: $GITHUB_APPS_INSTALLATION_TOKEN"
```

## Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `app_id` | GitHub App ID (numeric) | Yes | - |
| `installation_id` | GitHub App Installation ID (numeric) | Yes | - |
| `private_pem` | RSA private key in PEM format | Yes | - |
| `permissions` | YAML hash to restrict permissions | No | All app permissions |

## Outputs

| Output | Description |
|--------|-------------|
| `GITHUB_APPS_INSTALLATION_TOKEN` | Installation access token (valid for 1 hour) |

## Exit Codes

| Code | Meaning | Examples |
|------|---------|----------|
| `0` | Success | Token generated and exported |
| `1` | Validation Error | Missing app_id, invalid PEM format, malformed JSON |
| `2` | API Error | 401 (bad credentials), 404 (installation not found), network error |
| `3` | Envman Error | Token export failed |

## Troubleshooting

### Error: "App ID is required: set the app_id input parameter"

**Cause**: The `app_id` input is empty or not set.

**Solution**: Ensure you have set the `GITHUB_APP_ID` secret in Bitrise and referenced it correctly in your workflow.

### Error: "App ID must be numeric: received 'xxx'"

**Cause**: The app_id contains non-numeric characters.

**Solution**: Check your GitHub App settings page. The App ID should be a numeric value like `123456`.

### Error: "Invalid PEM format: ensure the key includes BEGIN/END RSA PRIVATE KEY markers"

**Cause**: The private key is missing the required `-----BEGIN` and `-----END` markers, or is corrupted.

**Solution**:
1. Re-download the private key from your GitHub App settings
2. Ensure the full key content (including headers) is stored in the secret
3. Check for extra whitespace or formatting issues (the step auto-normalizes whitespace)

### Error: "Authentication failed (HTTP 401): Invalid JWT or App ID"

**Cause**: The JWT signature is invalid, or the App ID doesn't match the private key.

**Solution**:
1. Verify the App ID matches your GitHub App
2. Ensure the private key is for the correct GitHub App
3. Check that the private key hasn't been regenerated (old keys become invalid)

### Error: "Installation not found (HTTP 404): Check installation_id"

**Cause**: The Installation ID doesn't exist, or the app isn't installed.

**Solution**:
1. Verify the installation ID is correct
2. Check that the GitHub App is installed on the target organization/account
3. Ensure the installation hasn't been uninstalled

### Error: "Permission denied (HTTP 403): App may not have access"

**Cause**: The app doesn't have permission to access the installation.

**Solution**:
1. Verify the app is installed on the target account
2. Check the app's permissions in GitHub settings
3. Ensure the installation hasn't been suspended

### Error: "Invalid permissions format"

**Cause**: The `permissions` input contains invalid syntax or Bitrise cannot serialize it.

**Solution**:
- Use YAML hash format:
  ```yaml
  - permissions:
      contents: read
      issues: write
  ```
- Check for correct YAML indentation (2 spaces per level)
- Ensure permission names are valid (see GitHub API docs)
- Test your workflow with `bitrise run test`

### Error: "GitHub API unavailable after retry (HTTP 503)"

**Cause**: GitHub API is temporarily unavailable or rate-limited.

**Solution**:
- Wait a few minutes and re-run the build
- Check [GitHub Status](https://www.githubstatus.com/) for API issues
- Verify you haven't exceeded GitHub API rate limits

### Token expires too quickly

**Behavior**: Installation tokens are valid for 1 hour by GitHub design.

**Solution**: Generate a new token in each workflow run. Don't try to cache or reuse tokens across builds.

## How to use this Step

Can be run directly with the [bitrise CLI](https://github.com/bitrise-io/bitrise),
just `git clone` this repository, `cd` into it's folder in your Terminal/Command Line
and call `bitrise run test`.

*Check the `bitrise.yml` file for required inputs which have to be
added to your `.bitrise.secrets.yml` file!*

Step by step:

1. Open up your Terminal / Command Line
2. `git clone` the repository
3. `cd` into the directory of the step (the one you just `git clone`d)
5. Create a `.bitrise.secrets.yml` file in the same directory of `bitrise.yml`
   (the `.bitrise.secrets.yml` is a git ignored file, you can store your secrets in it)
6. Check the `bitrise.yml` file for any secret you should set in `.bitrise.secrets.yml`
  * Best practice is to mark these options with something like `# define these in your .bitrise.secrets.yml`, in the `app:envs` section.
7. Once you have all the required secret parameters in your `.bitrise.secrets.yml` you can just run this step with the [bitrise CLI](https://github.com/bitrise-io/bitrise): `bitrise run test`

An example `.bitrise.secrets.yml` file:

```yaml
envs:
  # GitHub App ID - find this in your GitHub App settings under "About" → "App ID"
  - GITHUB_APP_ID: "123456"

  # GitHub App Installation ID - find this in the installation URL or via the GitHub API
  # Format: https://github.com/settings/installations/{installation_id}
  - GITHUB_INSTALLATION_ID: "789012"

  # GitHub App Private Key (PEM) - the .pem file you downloaded when creating the app
  # Include the full key with BEGIN/END markers
  - GITHUB_APP_PRIVATE_PEM: |
      -----BEGIN RSA PRIVATE KEY-----
      MIIEpAIBAAKCAQEA...
      ... (your private key content here) ...
      -----END RSA PRIVATE KEY-----
```

**Security Note**: Never commit `.bitrise.secrets.yml` to your repository. This file is already included in `.gitignore`.

## How to create your own step

1. Create a new git repository for your step (**don't fork** the *step template*, create a *new* repository)
2. Copy the [step template](https://github.com/bitrise-steplib/step-template) files into your repository
3. Fill the `step.sh` with your functionality
4. Wire out your inputs to `step.yml` (`inputs` section)
5. Fill out the other parts of the `step.yml` too
6. Provide test values for the inputs in the `bitrise.yml`
7. Run your step with `bitrise run test` - if it works, you're ready

__For Step development guidelines & best practices__ check this documentation: [https://github.com/bitrise-io/bitrise/blob/master/_docs/step-development-guideline.md](https://github.com/bitrise-io/bitrise/blob/master/_docs/step-development-guideline.md).

**NOTE:**

If you want to use your step in your project's `bitrise.yml`:

1. git push the step into it's repository
2. reference it in your `bitrise.yml` with the `git::PUBLIC-GIT-CLONE-URL@BRANCH` step reference style:

```
- git::https://github.com/user/my-step.git@branch:
   title: My step
   inputs:
   - my_input_1: "my value 1"
   - my_input_2: "my value 2"
```

You can find more examples of step reference styles
in the [bitrise CLI repository](https://github.com/bitrise-io/bitrise/blob/master/_examples/tutorials/steps-and-workflows/bitrise.yml#L65).

## How to contribute to this Step

1. Fork this repository
2. `git clone` it
3. Create a branch you'll work on
4. To use/test the step just follow the **How to use this Step** section
5. Do the changes you want to
6. Run/test the step before sending your contribution
  * You can also test the step in your `bitrise` project, either on your Mac or on [bitrise.io](https://www.bitrise.io)
  * You just have to replace the step ID in your project's `bitrise.yml` with either a relative path, or with a git URL format
  * (relative) path format: instead of `- original-step-id:` use `- path::./relative/path/of/script/on/your/Mac:`
  * direct git URL format: instead of `- original-step-id:` use `- git::https://github.com/user/step.git@branch:`
  * You can find more example of alternative step referencing at: https://github.com/bitrise-io/bitrise/blob/master/_examples/tutorials/steps-and-workflows/bitrise.yml
7. Once you're done just commit your changes & create a Pull Request


## Share your own Step

You can share your Step or step version with the [bitrise CLI](https://github.com/bitrise-io/bitrise). If you use the `bitrise.yml` included in this repository, all you have to do is:

1. In your Terminal / Command Line `cd` into this directory (where the `bitrise.yml` of the step is located)
1. Run: `bitrise run test` to test the step
1. Run: `bitrise run audit-this-step` to audit the `step.yml`
1. Check the `share-this-step` workflow in the `bitrise.yml`, and fill out the
   `envs` if you haven't done so already (don't forget to bump the version number if this is an update
   of your step!)
1. Then run: `bitrise run share-this-step` to share the step (version) you specified in the `envs`
1. Send the Pull Request, as described in the logs of `bitrise run share-this-step`

That's all ;)
