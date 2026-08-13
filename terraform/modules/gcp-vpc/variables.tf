variable "name" { type = string }
variable "subnets" { type = list(object({
  region   = string
  cidr     = string
  pod_cidr  = string
  svc_cidr  = string
})) }
variable "gke_control_plane_cidrs" { type = list(string) }
