include "env" { path = find_in_parent_folders("terragrunt.hcl") }
terraform { source = "terraform-google-modules/artifact-registry/google"; version = "~> 1.0" }
inputs = { repository_name = "multi-cloud-app"; location = "europe-west1"; format = "DOCKER"; description = "Multi-cloud DevOps portfolio app" }
