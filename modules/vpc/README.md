# VPC module (slim)

Opinionated **minimal** VPC for Lambda Managed Instances (use from the repo root, `examples/*`, or any caller):

- One **VPC** with DNS hostnames/support enabled
- **Public** and **private** subnets (one pair per AZ you pass in)
- **Internet gateway** and public route tables (`0.0.0.0/0` → IGW)
- **NAT gateway(s)** and private routes (`0.0.0.0/0` → NAT) when `enable_nat_gateway = true`
- Default **single NAT** in the first public subnet when `single_nat_gateway = true`

Not included (by design): IPv6, isolated/database tiers, custom NACLs, VPC interface endpoints, EKS subnet tags.

## Usage

```hcl
module "vpc" {
  source = "./modules/vpc"

  vpc_name   = "example"
  vpc_cidr   = "10.0.0.0/16"
  availability_zones   = ["ap-southeast-6a", "ap-southeast-6b"]
  public_subnet_cidrs  = ["10.0.0.0/24", "10.0.1.0/24"]
  private_subnet_cidrs = ["10.0.8.0/24", "10.0.9.0/24"]

  tags = {
    Project = "lmi-basic"
  }
}
```

Ensure `length(availability_zones) == length(public_subnet_cidrs) == length(private_subnet_cidrs)`.
