locals {
  all_config_users = distinct(flatten([
    for env in try(var.repo_config.environments, {}) : try(env.reviewers.users, [])
  ]))

  all_config_teams = distinct(flatten([
    for env in try(var.repo_config.environments, {}) : try(env.reviewers.teams, [])
  ]))

  valid_envs = keys(try(var.repo_config.environments, {}))

  env_vars = flatten([
    for var_name, scopes in try(var.repo_config.variables, {}) : [
      for scope, val in scopes : {
        id    = "${scope}-${var_name}"
        env   = scope
        name  = var_name
        value = tostring(val)
      } if scope != "_" && contains(local.valid_envs, scope)
    ]
  ])

  repo_vars = [
    for var_name, scopes in try(var.repo_config.variables, {}) : {
      name  = var_name
      value = tostring(scopes["_"])
    } if lookup(scopes, "_", null) != null
  ]

  orphaned_vars = flatten([
    for var_name, scopes in try(var.repo_config.variables, {}) : [
      for scope, val in scopes : "${var_name} in ${scope}"
      if scope != "_" && !contains(local.valid_envs, scope)
    ]
  ])

  env_secrets = flatten([
    for sec_name, scopes in try(var.repo_config.secrets, {}) : [
      for scope, val in scopes : {
        id       = "${scope}-${sec_name}"
        env      = scope
        sec_name = sec_name
      } if scope != "_" && contains(local.valid_envs, scope)
    ]
  ])

  repo_secrets = [
    for sec_name, scopes in try(var.repo_config.secrets, {}) : {
      sec_name = sec_name
    } if contains(keys(scopes), "_")
  ]

  unmanaged_envs = setsubtract(
    [for e in data.github_repository_environments.existing.environments : e.name],
    keys(try(var.repo_config.environments, {}))
  )
}
