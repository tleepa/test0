#!/bin/bash
set -euo pipefail

echo "Starting synchronization of GitHub branch protection"

if [ "$DRY_RUN" = "true" ]; then
  echo "Running in dry run mode - no changes will be made"
fi

protected_branches=$(yq eval '.protected_branches' "$CONFIG_FILE" 2>/dev/null)
if [ "$protected_branches" = "null" ] || [ -z "$protected_branches" ]; then
  echo "No protected branches configured"
  exit 0
fi

echo "Configuring repository merge settings..."
merge_settings='{
  "allow_merge_commit": false,
  "allow_squash_merge": true,
  "allow_rebase_merge": true,
  "allow_auto_merge": false,
  "delete_branch_on_merge": true,
  "squash_merge_commit_title": "PR_TITLE",
  "squash_merge_commit_message": "PR_BODY"
}'

if [ "$DRY_RUN" = "true" ]; then
  echo "Would update merge settings with: $merge_settings"
else
  echo "Updating merge settings with: $merge_settings"
  gh api -X PATCH "repos/$REPO" --input <(echo "$merge_settings")
fi

branches_list=$(yq eval '.protected_branches[]' "$CONFIG_FILE")

if [ -z "$branches_list" ]; then
  echo "No branches to protect"
  exit 0
fi

RULESET_NAME="Protected branches"
existing_ruleset=$(gh api "repos/$REPO/rulesets" --jq ".[] | select(.name == \"$RULESET_NAME\") | .id" 2>/dev/null || echo "")

branch_patterns=$(yq eval '.protected_branches[]' "$CONFIG_FILE" | jq -R . | jq -s .)

ruleset_payload=$(cat <<EOF
{
  "name": "$RULESET_NAME",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": $branch_patterns,
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "creation"
    },
    {
      "type": "update"
    },
    {
      "type": "deletion"
    },
    {
      "type": "required_linear_history"
    },
    {
      "type": "non_fast_forward"
    },
    {
      "type": "pull_request",
      "parameters": {
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_approving_review_count": 1,
        "required_review_thread_resolution": true
      }
    }
  ]
}
EOF
)

if [ -n "$existing_ruleset" ]; then
  if [ "$DRY_RUN" = "true" ]; then
    echo "Would update ruleset $RULESET_NAME"
  else
    echo "Updating existing ruleset (ID: $existing_ruleset)..."
    gh api -X PUT "repos/$REPO/rulesets/$existing_ruleset" --input <(echo "$ruleset_payload")
  fi
else
  if [ "$DRY_RUN" = "true" ]; then
    echo "Would create ruleset: $RULESET_NAME"
  else
    echo "Creating new ruleset: $RULESET_NAME"
    gh api -X POST "repos/$REPO/rulesets" --input <(echo "$ruleset_payload")
  fi
fi

echo "Branch protection synchronization complete"
