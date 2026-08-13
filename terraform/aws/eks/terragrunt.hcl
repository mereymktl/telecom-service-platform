include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

dependency "vpc" {
  config_path = "../vpc"
}

terraform {
  source = "../../modules/aws-eks"
}

inputs = {
  name                = "multi-cloud-aws"
  kubernetes_version  = "1.32"

  public_subnet_ids  = dependency.vpc.outputs.public_subnet_ids
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids

  endpoint_private_access = true
  endpoint_public_access  = true
  public_access_cidrs    = ["0.0.0.0/0"]

  system_instance_types = ["t3.medium"]
  system_desired_size   = 2
  system_min_size       = 2
  system_max_size       = 6

  app_instance_types = ["t3.large"]
  app_desired_size   = 3
  app_min_size       = 3
  app_max_size       = 12

  admin_role_arn = "arn:aws:sts::454690830753:assumed-role/AWSReservedSSO_AdministratorAccess_d0464ce5c356f955/customxer@mail.ru"

  log_retention_days = 30

  tags = {
    Environment = "production"
    Project     = "multi-cloud-devops"
  }
}