locals { aws_region = "eu-west-1"
environment = "production" }
remote_state {
  backend = "s3"
  config = {
    bucket         = "mereys-telecom-service-project"
    key            = "state-folder/${path_relative_to_include()}/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    use_lockfile   = true
  }
  generate = { path = "backend.tf"
  if_exists = "overwrite_terragrunt" }
}
generate "provider" {
  path = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<-EOT
    terraform {
      required_version = ">= 1.7.0"
      required_providers {
        aws = { source = "hashicorp/aws"
        version = "~> 5.0" }
        tls = { source = "hashicorp/tls"
        version = "~> 4.0" }
      }
    }
    provider "aws" { region = "eu-west-1" }
  EOT
}