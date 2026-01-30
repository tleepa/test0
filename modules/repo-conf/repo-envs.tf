resource "github_repository_environment" "envs" {
  for_each    = try(var.repo_config.environments, {})
  repository  = data.github_repository.repo.name
  environment = each.key

  wait_timer          = try(each.value.wait_timer, 0)
  prevent_self_review = try(each.value.prevent_self_review, false)

  dynamic "reviewers" {
    for_each = can(each.value.reviewers) ? [1] : []
    content {
      users = [
        for u in try(each.value.reviewers.users, []) : data.github_user.reviewers[u].id
      ]
      teams = [
        for t in try(each.value.reviewers.teams, []) : data.github_team.reviewers[t].id
      ]
    }
  }

  dynamic "deployment_branch_policy" {
    for_each = length(try(var.repo_config.protected_branches, [])) > 0 ? [1] : []
    content {
      protected_branches     = true
      custom_branch_policies = false
    }
  }
}
