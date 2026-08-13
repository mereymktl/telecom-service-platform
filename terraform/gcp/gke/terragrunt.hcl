include "env" { path = find_in_parent_folders("terragrunt.hcl") }
dependency "vpc" { config_path = "../vpc" }
terraform { source = "../../modules/gcp-gke" }
inputs = {
  name = "multi-cloud-gcp"; location = "europe-west1"; project_id = "multi-cloud-prod"
  network_name = dependency.vpc.outputs.network_name; subnet_name = dependency.vpc.outputs.subnet_names[0]
  enable_private_nodes = true; enable_private_endpoint = false; master_ipv4_cidr_block = "172.16.0.0/28"
  default_pool_count = 2; default_pool_min = 2; default_pool_max = 5
  spot_pool_count = 0; spot_pool_min = 0; spot_pool_max = 10
  env = "production"; team = "platform"
}
