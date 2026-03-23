# terraform-aws-lambda-managed-instance

Terraform modules and examples for **AWS Lambda Managed Instances (LMI)**—capacity providers in your VPC, functions that run on managed instance capacity, and optional supporting stacks.

## Modules

| Module | Role |
| --- | --- |
| [modules/vpc](modules/vpc/) | VPC with public and private subnets and a single NAT Gateway |
| [modules/lambda_managed_instance](modules/lambda_managed_instance/) | IAM, **CreateCapacityProvider**, and operator wiring for LMI in your subnets and security groups |
| [modules/lambda_managed_function](modules/lambda_managed_function/) | Execution role, log group, and **`aws_lambda_function`** with **`capacity_provider_config`** (publish-on-deploy, optional extra IAM policies) |

Use the modules from your own root module; paths can be local or `git::` (see [Terraform module sources](https://developer.hashicorp.com/terraform/language/modules/sources)).

```hcl
module "vpc" {
  source = "tfstack/lambda-managed-instance/aws//modules/vpc"
  # ...
}

module "lmi" {
  source = ""tfstack/lambda-managed-instance/aws//modules/lambda_managed_instance"
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [aws_security_group.app.id]
  # ...
}
```

## Repository layout

| Path | Purpose |
| --- | --- |
| **Root** (`main.tf`, `variables.tf`, …) | Smoke-test stack: VPC + security group + LMI + sample **Python 3.14** function—used by **`terraform test`** in CI |
| [examples/basic](examples/basic/) | Same stack as root; separate directory and state—see [examples/basic/README.md](examples/basic/README.md) |
| [examples/custom-scaling](examples/custom-scaling/) | Manual scaling mode and instance-type constraints—see [examples/custom-scaling/README.md](examples/custom-scaling/README.md) |
| [examples/waf-loki](examples/waf-loki/) | End-to-end demo: existing WAF log bucket → S3 event → **Node.js 24** LMI function → Loki + Grafana on EC2 behind an ALB—see [examples/waf-loki/README.md](examples/waf-loki/README.md) |
| [tests/stack.tftest.hcl](tests/stack.tftest.hcl) | **`terraform test`** with **`mock_provider "aws"`** (plan-only, no credentials) |

## Examples (summary)

- **Root / basic** — Fastest way to prove LMI in a fresh VPC (two AZs by default).
- **custom-scaling** — Shows **`scaling_mode = "Manual"`** and **`allowed_instance_types`** when you want explicit instance families.
- **waf-loki** — Full walkthrough-style path: S3 notifications, optional **WAFv2** logging to the same bucket, observability on private EC2, Grafana on a CIDR-restricted public ALB. Requires an **existing** S3 bucket, **archive** and **http** providers (declared in that example’s `versions.tf`), and a region where LMI is enabled.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
