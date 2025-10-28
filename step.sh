#!/bin/bash
set -e

# ==============================================================================
# GitHub Apps Installation Token Generator
# Bitrise Step for generating GitHub Apps installation tokens
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
    echo "Error: Required tools are missing: ${missing_tools[*]}"
    echo "Please install the missing tools and try again."
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
    echo "Error: App ID is required: set the app_id input parameter"
    exit $EXIT_VALIDATION_ERROR
  fi

  if ! [[ "$app_id" =~ ^[0-9]+$ ]]; then
    echo "Error: App ID must be numeric: received '$app_id'"
    exit $EXIT_VALIDATION_ERROR
  fi
}

# Validate input: installation_id (non-empty, numeric)
validate_installation_id() {
  local installation_id="$1"

  if [ -z "$installation_id" ]; then
    echo "Error: Installation ID is required: set the installation_id input parameter"
    exit $EXIT_VALIDATION_ERROR
  fi

  if ! [[ "$installation_id" =~ ^[0-9]+$ ]]; then
    echo "Error: Installation ID must be numeric: received '$installation_id'"
    exit $EXIT_VALIDATION_ERROR
  fi
}

# Validate PEM key (has BEGIN/END markers)
validate_pem() {
  local pem="$1"

  if [ -z "$pem" ]; then
    echo "Error: Private PEM key is required: set the private_pem input parameter"
    exit $EXIT_VALIDATION_ERROR
  fi

  # Check for BEGIN and END markers with PRIVATE KEY
  if ! echo "$pem" | grep -q "BEGIN.*PRIVATE KEY" || \
     ! echo "$pem" | grep -q "END.*PRIVATE KEY"; then
    echo "Error: Invalid PEM format: ensure the key includes BEGIN/END RSA PRIVATE KEY markers"
    exit $EXIT_VALIDATION_ERROR
  fi
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

  # TODO: Implement JWT generation and API call
  echo "Implementation in progress..."
}

# Run main function
main
