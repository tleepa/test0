resource "github_actions_variable" "repo_vars" {
  for_each = { for v in local.repo_vars : v.name => v }

  repository    = data.github_repository.repo.name
  variable_name = each.value.name
  value         = each.value.value
}

resource "github_actions_environment_variable" "env_vars" {
  for_each = { for v in local.env_vars : v.id => v }

  repository    = data.github_repository.repo.name
  environment   = github_repository_environment.envs[each.value.env].environment
  variable_name = each.value.name
  value         = each.value.value
}
