locals {
  env         = read_terragrunt_config(find_in_parent_folders("env.yaml"))
  aws_region  = local.env.locals.aws_region
  gcp_region  = local.env.locals.gcp_region
  gcp_project = local.env.locals.gcp_project
  common_tags = {
    Environment = local.env.locals.environment
    Project     = "multi-cloud-devops"
    ManagedBy   = "terragrunt"
    Owner       = "devops"
  }
}
