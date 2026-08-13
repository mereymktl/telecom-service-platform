variable "name"                     { type = string }
variable "vpc_cidr"                 { type = string }
variable "availability_zones"       { type = list(string) }
variable "aws_region"               { type = string }
variable "enable_nat_gateway"       { type = bool }
variable "flow_log_retention_days"  { type = number }
variable "tags"                     { type = map(string) }
