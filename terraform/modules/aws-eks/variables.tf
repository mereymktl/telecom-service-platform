variable "name"                    { type = string }
variable "kubernetes_version"      { type = string }
variable "public_subnet_ids"       { type = list(string) }
variable "private_subnet_ids"      { type = list(string) }
variable "endpoint_private_access" { type = bool }
variable "endpoint_public_access"  { type = bool }
variable "public_access_cidrs"     { type = list(string) }
variable "system_instance_types"   { type = list(string) }
variable "app_instance_types"      { type = list(string) }
variable "system_desired_size"     { type = number }
variable "system_min_size"         { type = number }
variable "system_max_size"         { type = number }
variable "app_desired_size"        { type = number }
variable "app_min_size"            { type = number }
variable "app_max_size"            { type = number }
variable "log_retention_days"      { type = number }
variable "tags"                    { type = map(string) }
variable "admin_role_arn" {
  description = "IAM role that should have administrative access to the EKS cluster"
  type        = string
}