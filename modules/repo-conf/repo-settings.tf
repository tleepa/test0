resource "github_repository" "repo_settings" {
  count = length(try(var.repo_config.protected_branches, [])) > 0 ? 1 : 0

  name = data.github_repository.repo.name

  allow_merge_commit     = false
  allow_squash_merge     = true
  allow_rebase_merge     = true
  allow_auto_merge       = false
  delete_branch_on_merge = true

  squash_merge_commit_title   = "PR_TITLE"
  squash_merge_commit_message = "PR_BODY"

  lifecycle {
    ignore_changes = [
      description,
      homepage_url,
      visibility,
      has_issues,
      has_projects,
      has_wiki,
      is_template,
      archived,
      archive_on_destroy,
      topics,
      vulnerability_alerts,
    ]
  }
}
