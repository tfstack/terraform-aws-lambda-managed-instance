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
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.4.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | >= 2.4.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_lambda_managed_function"></a> [lambda\_managed\_function](#module\_lambda\_managed\_function) | ./modules/lambda_managed_function | n/a |
| <a name="module_lambda_managed_instance"></a> [lambda\_managed\_instance](#module\_lambda\_managed\_instance) | ./modules/lambda_managed_instance | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ./modules/vpc | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_security_group.lmi](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [archive_file.lambda_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | Two AZs for public/private subnet pairs | `list(string)` | <pre>[<br/>  "ap-southeast-2a",<br/>  "ap-southeast-2b"<br/>]</pre> | no |
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region for all resources. Lambda Managed Instances (capacity providers) are only available in a subset of regions; see README. | `string` | `"ap-southeast-2"` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Prefix for VPC and Lambda resource names | `string` | `"lmi-basic"` | no |
| <a name="input_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#input\_private\_subnet\_cidrs) | Private subnet CIDRs (Lambda managed instances) | `list(string)` | <pre>[<br/>  "10.42.8.0/24",<br/>  "10.42.9.0/24"<br/>]</pre> | no |
| <a name="input_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#input\_public\_subnet\_cidrs) | Public subnet CIDRs (NAT + IGW path) | `list(string)` | <pre>[<br/>  "10.42.0.0/24",<br/>  "10.42.1.0/24"<br/>]</pre> | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Common tags | `map(string)` | `{}` | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | VPC IPv4 CIDR | `string` | `"10.42.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_capacity_provider_name"></a> [capacity\_provider\_name](#output\_capacity\_provider\_name) | n/a |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | n/a |
| <a name="output_lambda_log_group_name"></a> [lambda\_log\_group\_name](#output\_lambda\_log\_group\_name) | CloudWatch log group — tail logs or set alarms here |
| <a name="output_lambda_qualified_invoke_arn"></a> [lambda\_qualified\_invoke\_arn](#output\_lambda\_qualified\_invoke\_arn) | Use this ARN with aws lambda invoke (published version) |
| <a name="output_lambda_version"></a> [lambda\_version](#output\_lambda\_version) | Published Lambda version (use with function\_name for invoke) |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | n/a |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | n/a |
<!-- END_TF_DOCS -->
