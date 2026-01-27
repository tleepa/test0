data "github_repository" "repo" {
  full_name = "${var.github_org}/${var.repo_name}"
}

data "github_repository_environments" "existing" {
  repository = data.github_repository.repo.name
}

data "github_user" "reviewers" {
  for_each = { for u in local.all_config_users : u => u }
  username = each.value
}

data "github_team" "reviewers" {
  for_each = { for t in local.all_config_teams : t => t }
  slug     = each.value
}
