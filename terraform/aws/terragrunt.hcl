locals {
  aws_region = "eu-west-1"
  environment = "production"
}

remote_state {
  backend = "s3"

  config = {
    bucket       = "mereys-telecom-service-project"
    key          = "state-folder/${path_relative_to_include()}/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    dynamodb_table = "terraform-locks"
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<-EOT
    provider "aws" {
      region = "eu-west-1"
    }
  EOT
}