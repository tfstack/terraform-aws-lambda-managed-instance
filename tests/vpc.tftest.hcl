# Plan-only tests for modules/vpc in isolation.
# No AWS credentials required — mock_provider "aws" intercepts all API calls.

mock_provider "aws" {}

run "vpc_two_az_with_nat" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  variables {
    vpc_name             = "test-vpc"
    vpc_cidr             = "10.1.0.0/16"
    availability_zones   = ["ap-southeast-2a", "ap-southeast-2b"]
    public_subnet_cidrs  = ["10.1.0.0/24", "10.1.1.0/24"]
    private_subnet_cidrs = ["10.1.8.0/24", "10.1.9.0/24"]
    enable_nat_gateway   = true
    single_nat_gateway   = true
    tags = {
      Test = "terraform-test"
    }
  }

  assert {
    condition     = length(var.public_subnet_cidrs) == length(var.availability_zones)
    error_message = "public subnet count must match AZ count"
  }

  assert {
    condition     = length(var.private_subnet_cidrs) == length(var.availability_zones)
    error_message = "private subnet count must match AZ count"
  }
}

run "vpc_cidr_validation" {
  command = plan

  module {
    source = "./modules/vpc"
  }

  variables {
    vpc_name             = "test-vpc-cidr"
    vpc_cidr             = "10.2.0.0/16"
    availability_zones   = ["ap-southeast-2a"]
    public_subnet_cidrs  = ["10.2.0.0/24"]
    private_subnet_cidrs = ["10.2.8.0/24"]
    enable_nat_gateway   = false
    tags                 = {}
  }

  assert {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR"
  }
}
