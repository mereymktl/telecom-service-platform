include "env" {
  path = find_in_parent_folders("terragrunt.hcl")
}

terraform {
  source  = "terraform-aws-modules/ecr/aws"
}

inputs = {
  repository_name            = "multi-cloud-app"
  repository_image_tag_mutability = "IMMUTABLE"
}