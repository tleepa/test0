locals {
  repo_paths = fileset(path.module, "variables/**/*.y*ml")

  repos_config = {
    for filepath in local.repo_paths :
    trimsuffix(replace(filepath, "variables/", ""), ".yml") => {
      org         = split("/", filepath)[1]
      repo        = trimsuffix(basename(filepath), ".yml")
      config_data = yamldecode(file(filepath))
    }
  }
}

module "github_repositories" {
  source   = "./modules/repo-conf"
  for_each = local.repos_config

  github_org  = each.value.org
  repo_name   = each.value.repo
  repo_config = each.value.config_data
}

