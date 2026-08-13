include "env" { path = find_in_parent_folders("terragrunt.hcl") }
terraform { source = "../../modules/aws-vpc" }
inputs = {
  name = "multi-cloud-aws"
  vpc_cidr = "10.0.0.0/16"
  availability_zones = ["eu-west-1a","eu-west-1b","eu-west-1c"]
  aws_region = "eu-west-1"
  enable_nat_gateway = true
  flow_log_retention_days = 30
  tags = { Environment = "production"
  Project = "multi-cloud-devops" }
}
