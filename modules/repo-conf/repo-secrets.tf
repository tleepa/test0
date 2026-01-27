resource "github_actions_secret" "global" {
  for_each        = { for s in local.repo_secrets : s.sec_name => s }
  repository      = data.github_repository.repo.name
  secret_name     = each.value.sec_name
  plaintext_value = "REPLACE_ME"

  lifecycle {
    ignore_changes = [plaintext_value]
  }
}

resource "github_actions_environment_secret" "env_specific" {
  for_each        = { for s in local.env_secrets : s.id => s }
  repository      = data.github_repository.repo.name
  environment     = github_repository_environment.envs[each.value.env].environment
  secret_name     = each.value.sec_name
  plaintext_value = "REPLACE_ME"

  lifecycle {
    ignore_changes = [plaintext_value]
  }
}
