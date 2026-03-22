variable "aws_region" {
  description = "AWS region for all resources. Lambda Managed Instances are only available in a subset of regions; see repository README."
  type        = string
  default     = "ap-southeast-2"
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "lmi-custom"
}

variable "vpc_cidr" {
  description = "VPC IPv4 CIDR"
  type        = string
  default     = "10.1.0.0/16"
}

variable "availability_zones" {
  description = "AZs for subnet pairs"
  type        = list(string)
  default     = ["ap-southeast-2a", "ap-southeast-2b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (NAT + IGW path)"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs (Lambda managed instances)"
  type        = list(string)
  default     = ["10.1.101.0/24", "10.1.102.0/24"]
}

variable "tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  default     = {}
}
