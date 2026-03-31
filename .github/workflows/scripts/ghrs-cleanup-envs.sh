#!/bin/bash
set -euo pipefail

echo "Starting cleanup of unmanaged GitHub environments"

if [ "$DRY_RUN" = "true" ]; then
  echo "Running in dry run mode - no changes will be made"
fi

is_private=$(gh api "repos/$REPO" --jq '.private')

if [ "$is_private" != "true" ]; then
  echo "Resetting actions access level to: none"
  if [ "$DRY_RUN" = "true" ]; then
    echo "Would reset actions access level to: none"
  else
    gh api --method PUT "repos/$REPO/actions/permissions/access" --field "access_level=none"
  fi
fi

cleanup_unmanaged=$(yq eval '.cleanup_unmanaged.environments' "$CONFIG_FILE")
if [ "$cleanup_unmanaged" != "true" ]; then
  echo "Cleanup of unmanaged environments is disabled"
  exit 0
fi

managed_envs=$(yq eval '.environments | keys | .[]' "$CONFIG_FILE" 2>/dev/null | sort -u || echo "")

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
