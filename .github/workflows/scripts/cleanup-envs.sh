#!/bin/bash
set -euo pipefail

echo "Starting cleanup of unmanaged GitHub environments"

cleanup_unmanaged=$(yq eval '.cleanup_unmanaged.environments' "$CONFIG_FILE")
if [ "$cleanup_unmanaged" != "true" ]; then
  echo "Cleanup of unmanaged environments is disabled"
  exit 0
fi

if [ "$DRY_RUN" = "true" ]; then
  echo "Running in dry run mode - no changes will be made"
fi

managed_envs_from_vars=$(yq eval '.variables.[] | keys | .[]' "$CONFIG_FILE" 2>/dev/null | grep -v '^_$' | sort -u || echo "")
managed_envs_from_secrets=$(yq eval '.secrets.[] | keys | .[]' "$CONFIG_FILE" 2>/dev/null | grep -v '^_$' | sort -u || echo "")

managed_envs=$(echo -e "${managed_envs_from_vars}\n${managed_envs_from_secrets}" | sort -u | grep -v '^$')

if [ -z "$managed_envs" ]; then
  echo "No managed environments found in config"
  exit 0
fi

existing_envs=$(gh api "repos/$REPO/environments" --jq '.environments[].name' 2>/dev/null || echo "")

if [ -n "$existing_envs" ]; then
  echo "$existing_envs" | while read -r env_name; do
    if [ -z "$env_name" ]; then
      continue
    fi

    is_managed=$(echo "$managed_envs" | grep -x "$env_name" || echo "")

    if [ -z "$is_managed" ]; then
      echo "Deleting unmanaged environment: $env_name"
      if [ "$DRY_RUN" = "true" ]; then
        echo "Would delete environment: $env_name"
      else
        gh api -X DELETE "repos/$REPO/environments/$env_name"
      fi
    fi
  done
fi
