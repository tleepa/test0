output "check_orphans" {
  value = flatten(local.orphaned_vars)
}

output "unmanaged_environments" {
  value       = local.unmanaged_envs
  description = "Environments existing in GitHub but missing from YAML"
}
