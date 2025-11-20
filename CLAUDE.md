# bitrise-step-github-apps-installation-token Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-11-19

## Active Technologies
- Bash 4.x+ (POSIX-compatible shell script) + jq (JSON parsing/generation), envman (Bitrise environment management), openssl, curl, base64 (002-yaml-permissions-format)
- N/A (stateless operation, no persistent storage) (002-yaml-permissions-format)
- Bash 4.x+ (POSIX-compatible shell script) + jq (JSON validation - already required), envman (Bitrise environment management), openssl, curl, base64 (002-yaml-permissions-format)

- Bash 4.x+ (POSIX-compatible shell script) + openssl (RS256 JWT signing), curl (GitHub API calls), jq (JSON parsing), envman (Bitrise environment management - pre-installed), date (UTC time retrieval) (001-github-apps-token, 001-fix-jwt-clock-skew)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for Bash 4.x+ (POSIX-compatible shell script)

## Code Style

Bash 4.x+ (POSIX-compatible shell script): Follow standard conventions

## Recent Changes
- 001-fix-jwt-clock-skew: Added date (UTC time retrieval) for clock skew handling, JWT exp duration changed to 5 minutes (from 10), added clock validation (2020-2100 epoch range)
- 002-yaml-permissions-format: Added Bash 4.x+ (POSIX-compatible shell script) + jq (JSON validation - already required), envman (Bitrise environment management), openssl, curl, base64
- 002-yaml-permissions-format: Added Bash 4.x+ (POSIX-compatible shell script) + jq (JSON parsing/generation), envman (Bitrise environment management), openssl, curl, base64

- 001-github-apps-token: Added Bash 4.x+ (POSIX-compatible shell script) + openssl (RS256 JWT signing), curl (GitHub API calls), jq (JSON parsing), envman (Bitrise environment management - pre-installed)

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
