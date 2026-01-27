#!/bin/bash
set -euo pipefail

echo "Starting cleanup of unmanaged GitHub $1"

RESOURCE_TYPE="${1:-variables}"

if [ "$RESOURCE_TYPE" != "variables" ] && [ "$RESOURCE_TYPE" != "secrets" ]; then
  echo "Error: Invalid resource type. Use 'variables' or 'secrets'"
  exit 1
fi

cleanup_unmanaged=$(yq eval ".cleanup_unmanaged.${RESOURCE_TYPE}" "$CONFIG_FILE")
if [ "$cleanup_unmanaged" != "true" ]; then
  echo "Cleanup of unmanaged ${RESOURCE_TYPE} is disabled"
  exit 0
fi

if [ "$DRY_RUN" = "true" ]; then
  echo "Running in dry run mode - no changes will be made"
fi

if ! yq eval ".${RESOURCE_TYPE}" "$CONFIG_FILE" >/dev/null 2>&1; then
  echo "No ${RESOURCE_TYPE} defined in config"
  exit 0
fi

managed_items=$(yq eval ".${RESOURCE_TYPE} | keys | .[]" "$CONFIG_FILE" | sort)

existing_repo_items=$(gh ${RESOURCE_TYPE%s} list --repo "$REPO" --json name --jq '.[].name' 2>/dev/null || echo "")

if [ -n "$existing_repo_items" ]; then
  echo "$existing_repo_items" | while read -r existing_item; do
    if [ -z "$existing_item" ]; then
      continue
    fi

    is_managed=$(echo "$managed_items" | grep -x "$existing_item" || echo "")
    has_repo_scope="false"

    if [ -n "$is_managed" ]; then
      repo_value=$(yq eval ".${RESOURCE_TYPE}.${existing_item}._" "$CONFIG_FILE")
      if [ "$repo_value" != "null" ]; then
        has_repo_scope="true"
      fi
    fi

    if [ -z "$is_managed" ] || [ "$has_repo_scope" = "false" ]; then
      echo "Deleting unmanaged repository ${RESOURCE_TYPE%s}: $existing_item"
      if [ "$DRY_RUN" = "true" ]; then
        echo "Would delete repository ${RESOURCE_TYPE%s}: $existing_item"
      else
        gh ${RESOURCE_TYPE%s} delete "$existing_item" --repo "$REPO"
      fi
    fi
  done
fi

existing_envs=$(gh api "repos/$REPO/environments" --jq '.environments[].name' 2>/dev/null || echo "")

if [ -n "$existing_envs" ]; then
  echo "$existing_envs" | while read -r env_name; do
    if [ -z "$env_name" ]; then
      continue
    fi

    existing_env_items=$(gh ${RESOURCE_TYPE%s} list --env "$env_name" --repo "$REPO" --json name --jq '.[].name' 2>/dev/null || echo "")

    if [ -n "$existing_env_items" ]; then
      echo "$existing_env_items" | while read -r existing_item; do
        if [ -z "$existing_item" ]; then
          continue
        fi

        is_managed=$(echo "$managed_items" | grep -x "$existing_item" || echo "")
        has_env_scope="false"

        if [ -n "$is_managed" ]; then
          env_value=$(yq eval ".${RESOURCE_TYPE}.${existing_item}.${env_name}" "$CONFIG_FILE")
          if [ "$env_value" != "null" ]; then
            has_env_scope="true"
          fi
        fi

        if [ -z "$is_managed" ] || [ "$has_env_scope" = "false" ]; then
          echo "Deleting unmanaged environment ${RESOURCE_TYPE%s}: $env_name/$existing_item"
          if [ "$DRY_RUN" = "true" ]; then
            echo "Would delete environment ${RESOURCE_TYPE%s}: $env_name/$existing_item"
          else
            gh ${RESOURCE_TYPE%s} delete "$existing_item" --env "$env_name" --repo "$REPO"
          fi
        fi
      done
    fi
  done
fi
