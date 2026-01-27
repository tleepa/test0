#!/bin/bash
set -euo pipefail

echo "Starting synchronization of GitHub $1"

RESOURCE_TYPE="${1:-variables}"

if [ "$RESOURCE_TYPE" != "variables" ] && [ "$RESOURCE_TYPE" != "secrets" ]; then
  echo "Error: Invalid resource type. Use 'variables' or 'secrets'"
  exit 1
fi

if [ "$DRY_RUN" = "true" ]; then
  echo "Running in dry run mode - no changes will be made"
fi

if ! yq eval ".${RESOURCE_TYPE}" "$CONFIG_FILE" >/dev/null 2>&1; then
  echo "No ${RESOURCE_TYPE} defined in config"
  exit 0
fi

item_names=$(yq eval ".${RESOURCE_TYPE} | keys | .[]" "$CONFIG_FILE")

if [ -z "$item_names" ]; then
  exit 0
fi

echo "$item_names" | while read -r item_name; do
  if [ -z "$item_name" ]; then
    continue
  fi

  scopes=$(yq eval ".${RESOURCE_TYPE}.${item_name} | keys | .[]" "$CONFIG_FILE")

  echo "$scopes" | while read -r scope; do
    if [ -z "$scope" ]; then
      continue
    fi

    value=$(yq eval ".${RESOURCE_TYPE}.${item_name}.${scope}" "$CONFIG_FILE")

    if [ "$scope" = "_" ]; then
      if [ "$RESOURCE_TYPE" = "secrets" ]; then
        if gh secret list --repo "$REPO" --json name --jq '.[].name' | grep -qx "$item_name"; then
          echo "Repository secret exists: $item_name"
        else
          if [ "$DRY_RUN" = "true" ]; then
            echo "Would create repository secret: $item_name"
          else
            echo "REPLACE_ME" | gh secret set "$item_name" --repo "$REPO"
            echo "Created repository secret: $item_name"
          fi
        fi
      else
        if [ "$DRY_RUN" = "true" ]; then
          echo "Would set repository variable: $item_name=$value"
        else
          gh variable set "$item_name" --body "$value" --repo "$REPO"
        fi
      fi
    else
      if [ "$RESOURCE_TYPE" = "secrets" ]; then
        if gh secret list --env "$scope" --repo "$REPO" --json name --jq '.[].name' 2>/dev/null | grep -qx "$item_name"; then
          echo "Environment secret exists: $scope/$item_name"
        else
          if [ "$DRY_RUN" = "true" ]; then
            echo "Would create environment secret: $scope/$item_name"
          else
            echo "REPLACE_ME" | gh secret set "$item_name" --env "$scope" --repo "$REPO"
            echo "Created environment secret: $scope/$item_name"
          fi
        fi
      else
        if [ "$DRY_RUN" = "true" ]; then
          echo "Would set environment variable: $scope/$item_name=$value"
        else
          gh variable set "$item_name" --body "$value" --env "$scope" --repo "$REPO"
        fi
      fi
    fi
  done
done
