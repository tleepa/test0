resource "restapi_object" "repo_settings" {
  count = length(try(var.repo_config.protected_branches, [])) > 0 ? 1 : 0

  debug = true
  ignore_server_additions = true
  read_path   = "/repos/${var.github_org}/${var.repo_name}"

  create_method = "PATCH"
  path          = "/repos/${var.github_org}/${var.repo_name}"
  data = jsonencode({
    allow_merge_commit          = false
    allow_squash_merge          = true
    allow_rebase_merge          = true
    allow_auto_merge            = false
    delete_branch_on_merge      = true
    squash_merge_commit_title   = "PR_TITLE"
    squash_merge_commit_message = "PR_BODY"
  })

  update_method = "PATCH"
  update_path = "/repos/${var.github_org}/${var.repo_name}"
  update_data = jsonencode({
    allow_merge_commit          = false
    allow_squash_merge          = true
    allow_rebase_merge          = true
    allow_auto_merge            = false
    delete_branch_on_merge      = true
    squash_merge_commit_title   = "PR_TITLE"
    squash_merge_commit_message = "PR_BODY"
  })

  destroy_method = "PATCH"
  destroy_path = "/repos/${var.github_org}/${var.repo_name}"
  destroy_data = jsonencode({
    allow_merge_commit          = true
    allow_squash_merge          = true
    allow_rebase_merge          = true
    allow_auto_merge            = false
    delete_branch_on_merge      = false
    squash_merge_commit_title   = "COMMIT_OR_PR_TITLE"
    squash_merge_commit_message = "COMMIT_MESSAGES"
  })
}
