include "env" { path = find_in_parent_folders("terragrunt.hcl") }
terraform { source = "../../modules/gcp-vpc" }
inputs = {
  name = "multi-cloud-gcp"
  subnets = [
    { region = "europe-west1"; cidr = "10.1.0.0/20"; pod_cidr = "10.2.0.0/14"; svc_cidr = "10.6.0.0/20" },
    { region = "europe-west2"; cidr = "10.1.16.0/20"; pod_cidr = "10.2.64.0/14"; svc_cidr = "10.6.16.0/20" },
    { region = "europe-west3"; cidr = "10.1.32.0/20"; pod_cidr = "10.2.128.0/14"; svc_cidr = "10.6.32.0/20" },
  ]
  gke_control_plane_cidrs = ["172.16.0.0/28"]
}
