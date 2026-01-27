output "configuration_drift_report" {
  value = {
    for repo_path, mod in module.github_repositories :
    repo_path => {
      orphaned_vars  = try(mod.check_orphans, [])
      unmanaged_envs = try(mod.unmanaged_environments, [])
    }
    if length(try(mod.check_orphans, [])) > 0 || length(try(mod.unmanaged_environments, [])) > 0
  }
}
