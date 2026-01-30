resource "github_repository_ruleset" "branch_protection" {
  count = length(try(var.repo_config.protected_branches, [])) > 0 ? 1 : 0

  name        = "Protected branches"
  repository  = data.github_repository.repo.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = var.repo_config.protected_branches
      exclude = []
    }
  }

  rules {
    creation                = false
    update                  = false
    deletion                = false
    required_linear_history = true
    non_fast_forward        = true

    pull_request {
      dismiss_stale_reviews_on_push     = true
      require_code_owner_review         = false
      require_last_push_approval        = false
      required_approving_review_count   = 1
      required_review_thread_resolution = true
    }
  }
}
