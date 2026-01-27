#!/bin/bash
set -euo pipefail

# Validate YAML syntax
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Config file not found: $CONFIG_FILE"
  exit 1
fi

if ! yq eval '.' "$CONFIG_FILE" >/dev/null 2>&1; then
  echo "Invalid YAML syntax"
  exit 1
fi

# Validate variable names
yq eval '.variables | keys | .[]' "$CONFIG_FILE" | while read -r var_name; do
  if [ -n "$var_name" ]; then
    if ! echo "$var_name" | grep -qE '^[A-Z_][A-Z0-9_]*$'; then
      echo "Invalid variable name: $var_name"
      echo "Variable names must be uppercase letters, numbers, and underscores"
      exit 1
    fi
  fi
done

# Validate structure
if ! yq eval '.variables' "$CONFIG_FILE" >/dev/null 2>&1; then
  echo "'variables' section is required"
  exit 1
fi

yq eval '.variables | keys | .[]' "$CONFIG_FILE" | while read -r var_name; do
  scopes=$(yq eval ".variables.${var_name} | keys | length" "$CONFIG_FILE")
  if [ "$scopes" = "0" ] || [ "$scopes" = "null" ]; then
    echo "Variable $var_name has no scopes defined"
    exit 1
  fi
done

# Validate environment configurations
if ! yq eval '.environments' "$CONFIG_FILE" >/dev/null 2>&1; then
  exit 0
fi

env_names=$(yq eval '.environments | keys | .[]' "$CONFIG_FILE" 2>/dev/null || echo "")

if [ -n "$env_names" ]; then
  echo "$env_names" | while read -r env_name; do
    wait_timer=$(yq eval ".environments.${env_name}.wait_timer" "$CONFIG_FILE")
    if [ "$wait_timer" != "null" ]; then
      if ! echo "$wait_timer" | grep -qE '^[0-9]+$'; then
        echo "Invalid wait_timer for $env_name: must be a number"
        exit 1
      fi
      if [ "$wait_timer" -gt 43200 ]; then
        echo "Invalid wait_timer for $env_name: maximum is 43200 (30 days)"
        exit 1
      fi
    fi

    prevent_self_review=$(yq eval ".environments.${env_name}.prevent_self_review" "$CONFIG_FILE")
    if [ "$prevent_self_review" != "null" ] && [ "$prevent_self_review" != "true" ] && [ "$prevent_self_review" != "false" ]; then
      echo "Invalid prevent_self_review for $env_name: must be true or false"
      exit 1
    fi
  done
fi
