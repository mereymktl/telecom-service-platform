locals { gcp_region = "europe-west1"; gcp_project = "cloud-prod-503017"; environment = "production" }
remote_state {
  backend = "gcs"
  config = { bucket = "multi-cloud-prod-terraform-state"; prefix = "gcp/${path_relative_to_include()}" }
  generate = { path = "backend.tf"; if_exists = "overwrite_terragrunt" }
}
generate "provider" {
  path = "provider.tf"; if_exists = "overwrite_terragrunt"
  contents = <<-EOT
    terraform { required_version = ">= 1.7.0"; required_providers { google = { source = "hashicorp/google"; version = "~> 5.0" } google-beta = { source = "hashicorp/google-beta"; version = "~> 5.0" } } }
    provider "google" { region = "europe-west1"; project = "cloud-prod-503017" }
    provider "google-beta" { region = "europe-west1"; project = "cloud-prod-503017" }
  EOT
}
