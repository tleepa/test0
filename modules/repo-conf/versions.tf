terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    restapi = {
      source  = "Mastercard/restapi"
      version = "3.0.0-rc2"
    }
  }
}
