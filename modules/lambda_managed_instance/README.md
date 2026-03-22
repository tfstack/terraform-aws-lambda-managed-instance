# lambda_managed_instance

Terraform module that provisions a Lambda Managed Instance (LMI) **capacity provider** — the shared EC2 fleet for one or more LMI Lambda functions. Deploy one of these per fleet, then use **`lambda_managed_function`** for each function that should run on it.

## Resources created

| Resource | Purpose |
| --- | --- |
| `aws_iam_service_linked_role` | Fleet lifecycle SLR (import if it already exists in the account) |
| `aws_iam_role` operator | Capacity provider operator role (`AWSLambdaManagedEC2ResourceOperator`) |
| `aws_lambda_capacity_provider` | Fleet placement: VPC, subnets, SGs, instance requirements, scaling policy |

## Required inputs

| Variable | Type | Description |
| --- | --- | --- |
| `capacity_provider_name` | string | Capacity provider name (must be unique in the account) |
| `subnet_ids` | set(string) | Private subnet IDs for managed instances |
| `security_group_ids` | set(string) | Security groups for capacity provider ENIs |

## Optional inputs

### Capacity provider & scaling

| Variable | Default | Description |
| --- | --- | --- |
| `architectures` | `["x86_64"]` | `["x86_64"]` or `["arm64"]` — must match all lambda_managed_function modules on this provider |
| `max_vcpu_count` | `16` | Maximum vCPUs in the capacity provider pool |
| `scaling_mode` | `"Auto"` | `"Auto"` (Lambda-managed) or `"Manual"` (CPU target policy) |
| `cpu_target_utilization` | `70` | CPU target % for `scaling_mode = "Manual"` |
| `allowed_instance_types` | `[]` | Allowlist of EC2 instance types. Mutually exclusive with `excluded_instance_types`. |
| `excluded_instance_types` | `[]` | Denylist of EC2 instance types; supports wildcards. Mutually exclusive with `allowed_instance_types`. |

### IAM

| Variable | Default | Description |
| --- | --- | --- |
| `iam_role_name_prefix` | `"lmi"` | Prefix for the operator role name |

### Common

| Variable | Default | Description |
| --- | --- | --- |
| `tags` | `{}` | Tags applied to all taggable resources |

## Key constraints

- **First capacity provider in an account** requires `iam:CreateServiceLinkedRole`. If the SLR already exists, import it before the first `apply`:

  ```bash
  terraform import module.<name>.aws_iam_service_linked_role.lambda_lmi \
    arn:aws:iam::<ACCOUNT_ID>:role/aws-service-role/lambda.amazonaws.com/AWSServiceRoleForLambda
  ```

- **`allowed_instance_types` and `excluded_instance_types` are mutually exclusive** — set at most one.
- **`architectures`** must match every `lambda_managed_function` module that references `capacity_provider_arn`.
- **Scaling:** With `scaling_mode = "Auto"`, no `scaling_policies` are sent. Set `scaling_mode = "Manual"` to activate the CPU target policy.
- **Destroy order:** `aws_lambda_capacity_provider` depends on `aws_iam_service_linked_role` — Terraform handles this automatically.

## Usage

```hcl
module "lmi_fleet" {
  source = "./modules/lambda_managed_instance"

  capacity_provider_name = "my-fleet"
  iam_role_name_prefix   = "my-fleet"

  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [aws_security_group.lmi.id]

  tags = { Project = "demo" }
}

module "my_fn" {
  source = "./modules/lambda_managed_function"

  function_name         = "my-fn"
  capacity_provider_arn = module.lmi_fleet.capacity_provider_arn

  filename         = data.archive_file.fn.output_path
  source_code_hash = data.archive_file.fn.output_base64sha256

  tags = { Project = "demo" }
}
```

## Outputs

| Output | Description |
| --- | --- |
| `capacity_provider_arn` | Capacity provider ARN (pass to `lambda_managed_function`) |
| `capacity_provider_name` | Capacity provider name |
| `operator_role_arn` | Operator role ARN |
