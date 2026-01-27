#!/bin/bash
set -euo pipefail

echo "Starting synchronization of GitHub environments from variables"

if [ "$DRY_RUN" = "true" ]; then
  echo "Running in dry run mode - no changes will be made"
fi

environments=$(yq eval '.variables.[] | keys | .[]' "$CONFIG_FILE" | grep -v '^_$' | sort -u)

if [ -z "$environments" ]; then
  exit 0
fi

echo "$environments" | while read -r env_name; do
  if [ -n "$env_name" ]; then
    echo "Processing environment: $env_name"

    if gh api "repos/$REPO/environments/$env_name" >/dev/null 2>&1; then
      echo "Environment already exists: $env_name"
    else
      if [ "$DRY_RUN" = "true" ]; then
        echo "Would create environment: $env_name"
      else
        echo "Creating environment: $env_name"
        gh api -X PUT "repos/$REPO/environments/$env_name"
      fi
    fi

    env_config_exists=$(yq eval ".environments.${env_name}" "$CONFIG_FILE" 2>/dev/null)

    if [ "$env_config_exists" != "null" ]; then
      echo "Configuring environment: $env_name"
      config_json="{}"

      wait_timer=$(yq eval ".environments.${env_name}.wait_timer" "$CONFIG_FILE")
      if [ "$wait_timer" != "null" ]; then
        config_json=$(jq --argjson timer "$wait_timer" '.wait_timer = $timer' <<<"$config_json")
      fi

      prevent_self_review=$(yq eval ".environments.${env_name}.prevent_self_review" "$CONFIG_FILE")
      if [ "$prevent_self_review" != "null" ]; then
        config_json=$(jq --argjson prevent "$prevent_self_review" '.prevent_self_review = $prevent' <<<"$config_json")
      fi

      reviewers=$(yq eval ".environments.${env_name}.reviewers" "$CONFIG_FILE" 2>/dev/null)
      if [ "$reviewers" != "null" ] && [ -n "$reviewers" ]; then
        reviewers_json=$(yq eval ".environments.${env_name}.reviewers" "$CONFIG_FILE" -o=json)

        # Fetch user IDs for user logins
        user_reviewers="[]"
        users=$(jq -r '.users[]? // empty' <<<"$reviewers_json")
        if [ -n "$users" ]; then
          while IFS= read -r username; do
            if [ -n "$username" ]; then
              user_id=$(gh api "users/$username" --jq '.id')
              user_reviewers=$(jq --argjson id "$user_id" '. += [{"type": "User", "id": $id}]' <<<"$user_reviewers")
            fi
          done <<<"$users"
        fi

        # Fetch team IDs for team slugs
        team_reviewers="[]"
        teams=$(jq -r '.teams[]? // empty' <<<"$reviewers_json")
        if [ -n "$teams" ]; then
          repo_owner=$(echo "$REPO" | cut -d'/' -f1)
          while IFS= read -r team_slug; do
            if [ -n "$team_slug" ]; then
              team_id=$(gh api "orgs/$repo_owner/teams/$team_slug" --jq '.id')
              team_reviewers=$(jq --argjson id "$team_id" '. += [{"type": "Team", "id": $id}]' <<<"$team_reviewers")
            fi
          done <<<"$teams"
        fi

        reviewers_payload=$(jq -s '.[0] + .[1]' <<<"$user_reviewers"$'\n'"$team_reviewers")

        if [ "$reviewers_payload" != "[]" ]; then
          config_json=$(jq --argjson reviewers "$reviewers_payload" '.reviewers = $reviewers' <<<"$config_json")
        fi
      fi

      deployment_branches=$(yq eval ".environments.${env_name}.deployment_branches" "$CONFIG_FILE" 2>/dev/null)
      if [ "$deployment_branches" != "null" ] && [ -n "$deployment_branches" ]; then
        config_json=$(jq '.deployment_branch_policy = {"protected_branches": false, "custom_branch_policies": true}' <<<"$config_json")
      fi

      if [ "$config_json" != "{}" ]; then
        if [ "$DRY_RUN" = "true" ]; then
          echo "Would configure environment $env_name with: $config_json"
        else
          gh api -X PUT "repos/$REPO/environments/$env_name" --input <(echo "$config_json")
        fi
      fi

      if [ "$deployment_branches" != "null" ] && [ -n "$deployment_branches" ]; then
        branches_list=$(yq eval ".environments.${env_name}.deployment_branches[]" "$CONFIG_FILE")
        echo "$branches_list" | while read -r branch_pattern; do
          if [ -n "$branch_pattern" ]; then
            if [ "$DRY_RUN" = "true" ]; then
              echo "Would add deployment branch pattern for $env_name: $branch_pattern"
            else
              echo "Adding deployment branch pattern for $env_name: $branch_pattern"
              gh api -X POST "repos/$REPO/environments/$env_name/deployment-branch-policies" -f name="$branch_pattern"
            fi
          fi
        done
      fi
    fi
  fi
done
