#!/bin/bash
set -e

# ==============================================================================
# GitHub Apps Installation Token Generator
# Bitrise Step for generating GitHub Apps installation tokens
#
# This script generates a GitHub Apps Installation Token by:
# 1. Validating required tools (openssl, curl, jq, envman, base64)
# 2. Validating input parameters (app_id, installation_id, private_pem)
# 3. Generating a JWT (JSON Web Token) signed with the app's private key
# 4. Calling the GitHub API to exchange JWT for an installation token
# 5. Exporting the token to GITHUB_APPS_INSTALLATION_TOKEN environment variable
#
# Usage Example:
#   export app_id="123456"
#   export installation_id="789012"
#   export private_pem="$(cat app-private-key.pem)"
#   export permissions='{"contents":"read","issues":"write"}'  # Optional
#   ./step.sh
#
# Required Environment Variables:
#   - app_id: GitHub App ID (numeric)
#   - installation_id: GitHub App Installation ID (numeric)
#   - private_pem: RSA private key in PEM format (with BEGIN/END markers)
#
# Optional Environment Variables:
#   - permissions: JSON object to restrict token permissions (default: all app permissions)
#
# Output:
#   - GITHUB_APPS_INSTALLATION_TOKEN: Installation access token (valid for 1 hour)
#
# Exit Codes:
#   0 - Success: Token generated and exported
#   1 - Validation Error: Invalid inputs or missing tools
#   2 - API Error: GitHub API request failed
#   3 - Envman Error: Failed to export token to environment
#
# Security:
#   - Private keys stored in temp files with 0600 permissions
#   - Sensitive operations protected with 'set +x' to prevent logging
#   - Temp files cleaned up on all exit paths (trap handler)
#
# ==============================================================================

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_VALIDATION_ERROR=1
readonly EXIT_API_ERROR=2
readonly EXIT_ENVMAN_ERROR=3

# Global variables for cleanup
TEMP_PEM_FILE=""

# ==============================================================================
# Utility Functions
# ==============================================================================

# Base64url encoding (RFC 4648 Section 5)
# Removes newlines, replaces +/ with -_, removes padding =
base64url_encode() {
  base64 | tr -d '\n' | tr '+/' '-_' | tr -d '='
}

# ==============================================================================
# Cleanup Handler
# ==============================================================================

cleanup() {
  # Remove temporary PEM file if it exists
  if [ -n "$TEMP_PEM_FILE" ] && [ -f "$TEMP_PEM_FILE" ]; then
    rm -f "$TEMP_PEM_FILE"
  fi
}

# Register cleanup handler for all exit signals
trap cleanup EXIT ERR INT TERM

# ==============================================================================
# Validation Functions
# ==============================================================================

# Validate required tools are installed
validate_tools() {
  local missing_tools=()

  for tool in openssl curl jq envman base64; do
    if ! command -v "$tool" &> /dev/null; then
      missing_tools+=("$tool")
    fi
  done

  if [ ${#missing_tools[@]} -gt 0 ]; then
    echo "Error: Required tools are missing: ${missing_tools[*]}" >&2
    echo "Please install the missing tools and try again." >&2
    exit $EXIT_VALIDATION_ERROR
  fi
}

# Normalize PEM key (trim whitespace, normalize line breaks)
normalize_pem() {
  local pem="$1"

  # Trim leading/trailing whitespace and normalize line endings
  echo "$pem" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | tr -d '\r'
}

# Validate input: app_id (non-empty, numeric)
validate_app_id() {
  local app_id="$1"

  if [ -z "$app_id" ]; then
    echo "Error: App ID is required: set the app_id input parameter" >&2
    exit $EXIT_VALIDATION_ERROR
  fi

  if ! [[ "$app_id" =~ ^[0-9]+$ ]]; then
    echo "Error: App ID must be numeric: received '$app_id'" >&2
    exit $EXIT_VALIDATION_ERROR
  fi
}

# Validate input: installation_id (non-empty, numeric)
validate_installation_id() {
  local installation_id="$1"

  if [ -z "$installation_id" ]; then
    echo "Error: Installation ID is required: set the installation_id input parameter" >&2
    exit $EXIT_VALIDATION_ERROR
  fi

  if ! [[ "$installation_id" =~ ^[0-9]+$ ]]; then
    echo "Error: Installation ID must be numeric: received '$installation_id'" >&2
    exit $EXIT_VALIDATION_ERROR
  fi
}

# Validate PEM key (has BEGIN/END markers)
validate_pem() {
  local pem="$1"

  if [ -z "$pem" ]; then
    echo "Error: Private PEM key is required: set the private_pem input parameter" >&2
    exit $EXIT_VALIDATION_ERROR
  fi

  # Check for BEGIN and END markers with PRIVATE KEY
  if ! echo "$pem" | grep -q "BEGIN.*PRIVATE KEY" || \
     ! echo "$pem" | grep -q "END.*PRIVATE KEY"; then
    echo "Error: Invalid PEM format: ensure the key includes BEGIN/END RSA PRIVATE KEY markers" >&2
    exit $EXIT_VALIDATION_ERROR
  fi
}

# ==============================================================================
# JWT Generation Functions
# ==============================================================================

# Create JWT header (T012)
create_jwt_header() {
  echo -n '{"alg":"RS256","typ":"JWT"}' | base64url_encode
}

# Create JWT payload with iat/exp/iss claims (T013)
create_jwt_payload() {
  local app_id="$1"
  local now
  now=$(date +%s)
  local iat=$((now - 60))  # Issued 60 seconds ago (clock drift protection)
  local exp=$((now + 600)) # Expires in 600 seconds (10 minutes)

  echo -n "{\"iat\":${iat},\"exp\":${exp},\"iss\":\"${app_id}\"}" | base64url_encode
}

# Create temporary PEM file with secure permissions (T014)
create_temp_pem_file() {
  local pem_content="$1"

  # Create temporary file
  TEMP_PEM_FILE=$(mktemp)

  # Write PEM content to file
  echo "$pem_content" > "$TEMP_PEM_FILE"

  # Set restrictive permissions (0600 = owner read/write only)
  chmod 0600 "$TEMP_PEM_FILE"

  echo "$TEMP_PEM_FILE"
}

# Sign JWT data with openssl (T015)
sign_jwt() {
  local data="$1"
  local pem_file="$2"

  echo -n "$data" | openssl dgst -sha256 -sign "$pem_file" | base64url_encode
}

# Generate complete JWT (header.payload.signature) (T016)
generate_jwt() {
  local app_id="$1"
  local pem_content="$2"

  # Disable command echoing for sensitive operations (T022)
  set +x

  # Create header and payload
  local header
  local payload
  header=$(create_jwt_header)
  payload=$(create_jwt_payload "$app_id")

  # Create temporary PEM file
  local pem_file
  pem_file=$(create_temp_pem_file "$pem_content")

  # Sign the JWT
  local signature
  signature=$(sign_jwt "${header}.${payload}" "$pem_file")

  # Construct final JWT
  local jwt="${header}.${payload}.${signature}"

  # Re-enable command echoing
  set -e

  echo "$jwt"
}

# ==============================================================================
# GitHub API Functions
# ==============================================================================

# Call GitHub API to create installation token (T017)
call_github_api() {
  local installation_id="$1"
  local jwt="$2"
  local permissions_json="$3"

  # Disable command echoing for sensitive operations (T022)
  set +x

  local response
  local url="https://api.github.com/app/installations/${installation_id}/access_tokens"

  # Build curl command
  if [ -n "$permissions_json" ]; then
    # With custom permissions
    response=$(curl -s -w "\n%{http_code}" -X POST \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${jwt}" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -H "User-Agent: bitrise-step-github-apps-installation-token" \
      -H "Content-Type: application/json" \
      -d "$permissions_json" \
      "$url" 2>&1)
  else
    # Without custom permissions
    response=$(curl -s -w "\n%{http_code}" -X POST \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer ${jwt}" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      -H "User-Agent: bitrise-step-github-apps-installation-token" \
      "$url" 2>&1)
  fi

  # Re-enable command echoing
  set -e

  echo "$response"
}

# Parse HTTP response (status code and body separation) (T018)
parse_http_response() {
  local response="$1"

  local http_code
  local body

  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')

  echo "${http_code}|${body}"
}

# Extract token from JSON response using jq (T019)
extract_token() {
  local json_body="$1"

  local token
  token=$(echo "$json_body" | jq -r '.token // empty')

  if [ -z "$token" ]; then
    echo "Error: Failed to extract token from API response" >&2
    exit $EXIT_API_ERROR
  fi

  echo "$token"
}

# Export token to environment with envman (T020)
export_token() {
  local token="$1"

  # Disable command echoing for sensitive operations (T022)
  set +x

  # Export token using envman
  if ! echo "$token" | envman add --key GITHUB_APPS_INSTALLATION_TOKEN; then
    echo "Error: Failed to export token to environment: envman returned non-zero exit code" >&2
    exit $EXIT_ENVMAN_ERROR
  fi

  # Re-enable command echoing
  set -e
}

# Log success message with expiration time (T021)
log_success() {
  local json_body="$1"

  local expires_at
  expires_at=$(echo "$json_body" | jq -r '.expires_at // "1 hour from now"')

  echo "Success: GitHub Apps Installation Token generated"
  echo "Token expires at: ${expires_at}"
  echo "Token exported to: GITHUB_APPS_INSTALLATION_TOKEN"
}

# Handle API errors with retry logic
handle_api_error() {
  local http_code="$1"
  local body="$2"
  local attempt="$3"

  # Extract error message from response
  local error_message
  error_message=$(echo "$body" | jq -r '.message // "Unknown error"')

  case "$http_code" in
    503|429)
      if [ "$attempt" -eq 1 ]; then
        echo "API temporarily unavailable (HTTP ${http_code}), retrying in 5 seconds..."
        sleep 5
        return 0  # Indicate retry
      else
        echo "Error: GitHub API unavailable after retry (HTTP ${http_code}): ${error_message}" >&2
        exit $EXIT_API_ERROR
      fi
      ;;
    401)
      echo "Error: Authentication failed (HTTP 401): Invalid JWT or App ID" >&2
      echo "Details: ${error_message}" >&2
      exit $EXIT_API_ERROR
      ;;
    404)
      echo "Error: Installation not found (HTTP 404): Check installation_id" >&2
      echo "Details: ${error_message}" >&2
      exit $EXIT_API_ERROR
      ;;
    403)
      echo "Error: Permission denied (HTTP 403): App may not have access" >&2
      echo "Details: ${error_message}" >&2
      exit $EXIT_API_ERROR
      ;;
    422)
      echo "Error: Invalid request (HTTP 422): Check permissions format" >&2
      echo "Details: ${error_message}" >&2
      exit $EXIT_API_ERROR
      ;;
    *)
      echo "Error: GitHub API request failed (HTTP ${http_code})" >&2
      echo "Details: ${error_message}" >&2
      exit $EXIT_API_ERROR
      ;;
  esac
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
  echo "GitHub Apps Installation Token Generator"
  echo "========================================"

  # Validate required tools
  validate_tools

  # Validate inputs
  validate_app_id "$app_id"
  validate_installation_id "$installation_id"

  # Normalize and validate PEM key
  local normalized_pem
  normalized_pem=$(normalize_pem "$private_pem")
  validate_pem "$normalized_pem"

  echo "Validation complete"

  # Generate JWT
  echo "Generating JWT..."
  local jwt
  jwt=$(generate_jwt "$app_id" "$normalized_pem")

  # Prepare permissions JSON if provided
  local permissions_json=""
  if [ -n "$permissions" ]; then
    # Check if permissions is a Go map format (e.g., "map[key:value ...]")
    # Bitrise passes YAML hashes as Go map string representations
    if [[ "$permissions" =~ ^map\[.*\]$ ]]; then
      # Convert Go map format to JSON
      # Extract key:value pairs from "map[key1:value1 key2:value2]"
      local map_content="${permissions#map[}"  # Remove "map[" prefix
      map_content="${map_content%]}"           # Remove "]" suffix

      # Build JSON object from key:value pairs
      local json_obj="{"
      local first=true
      while IFS=: read -r key value; do
        # Trim whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)

        if [ -n "$key" ] && [ -n "$value" ]; then
          if [ "$first" = false ]; then
            json_obj+=","
          fi
          json_obj+="\"$key\":\"$value\""
          first=false
        fi
      done < <(echo "$map_content" | tr ' ' '\n')
      json_obj+="}"

      permissions_json="{\"permissions\":${json_obj}}"
    else
      # Assume it's already JSON format (for backward compatibility or direct JSON input)
      # Validate JSON format
      if ! echo "$permissions" | jq empty 2>/dev/null; then
        echo "Error: Invalid permissions format" >&2
        echo "Expected: YAML hash (e.g., contents: read) or valid JSON string" >&2
        echo "Received: $permissions" >&2
        exit $EXIT_VALIDATION_ERROR
      fi
      permissions_json="{\"permissions\":${permissions}}"
    fi
  fi

  # Call GitHub API with retry logic
  echo "Calling GitHub API..."
  local response
  local http_code
  local body
  local attempt=1

  while true; do
    response=$(call_github_api "$installation_id" "$jwt" "$permissions_json")

    # Parse response
    local parsed
    parsed=$(parse_http_response "$response")
    http_code=$(echo "$parsed" | cut -d'|' -f1)
    body=$(echo "$parsed" | cut -d'|' -f2-)

    # Check for success
    if [ "$http_code" = "201" ] || [ "$http_code" = "200" ]; then
      break
    fi

    # Handle error (may retry)
    if ! handle_api_error "$http_code" "$body" "$attempt"; then
      break  # Don't retry
    fi

    attempt=$((attempt + 1))
  done

  # Extract token from response
  local token
  token=$(extract_token "$body")

  # Export token to environment
  export_token "$token"

  # Log success
  log_success "$body"

  exit $EXIT_SUCCESS
}

# Run main function
main
