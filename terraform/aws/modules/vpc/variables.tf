variable "cluster_name" {
  description = "Name prefix used for all resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "List of AZs to deploy into (us-west-1 has 2: us-west-1a, us-west-1c)"
  type        = list(string)
  default     = ["us-west-1a", "us-west-1c"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets — must match length of availability_zones"
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets — must match length of availability_zones"
  type        = list(string)
  default     = ["10.0.10.0/23", "10.0.12.0/23"]
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway (cheaper for dev). Set false for HA production."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
