variable "vpc_name" {
  description = "Name tag for the VPC and related resources"
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR for the VPC"
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "availability_zones" {
  description = "AZs for subnets (one public and one private CIDR per AZ, same order)"
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) > 0
    error_message = "Provide at least one availability zone."
  }
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (one per AZ, same length as availability_zones)"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == length(var.availability_zones)
    error_message = "public_subnet_cidrs must have the same length as availability_zones."
  }
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs (one per AZ, same length as availability_zones)"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == length(var.availability_zones)
    error_message = "private_subnet_cidrs must have the same length as availability_zones."
  }
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "enable_nat_gateway" {
  description = "When true, create a NAT gateway so private subnets reach the internet"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "When true, use one NAT gateway in the first public subnet (cheaper; single-AZ egress path)"
  type        = bool
  default     = true
}
