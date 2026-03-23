variable "aws_region" {
  description = "AWS region for all resources. Lambda Managed Instances (capacity providers) are only available in a subset of regions; see README."
  type        = string
  default     = "ap-southeast-2"
}

variable "name_prefix" {
  description = "Prefix for VPC and Lambda resource names"
  type        = string
  default     = "lmi-basic"
}

variable "vpc_cidr" {
  description = "VPC IPv4 CIDR"
  type        = string
  default     = "10.42.0.0/16"
}

variable "availability_zones" {
  description = "Two AZs for public/private subnet pairs"
  type        = list(string)
  default     = ["ap-southeast-2a", "ap-southeast-2b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (NAT + IGW path)"
  type        = list(string)
  default     = ["10.42.0.0/24", "10.42.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs (Lambda managed instances)"
  type        = list(string)
  default     = ["10.42.8.0/24", "10.42.9.0/24"]
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
