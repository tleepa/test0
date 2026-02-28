terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 3.0"
    }
  }
}

provider "github" {}

provider "restapi" {
  uri                  = "https://api.github.com"
  write_returns_object = true
  headers = {
    Authorization = "Bearer ${var.github_token}"
    Accept        = "application/vnd.github+json"
  }
}
