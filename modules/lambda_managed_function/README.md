# lambda_managed_function

Terraform module that deploys a single Lambda function onto an existing Lambda Managed Instance (LMI) capacity provider. Call this module once per function; all functions can share the same `lambda_managed_instance` module output.

## Resources created

| Resource | Purpose |
| --- | --- |
| `aws_iam_role` execution | Lambda execution role (`AWSLambdaBasicExecutionRole` + any `additional_execution_policy_arns`) |
| `aws_cloudwatch_log_group` | Pre-created log group with configurable retention |
| `aws_lambda_function` | Published LMI function with configurable logging, environment, layers, and concurrency |

## Required inputs

| Variable | Type | Description |
| --- | --- | --- |
| `function_name` | string | Lambda function name |
| `capacity_provider_arn` | string | ARN of the capacity provider (output of `lambda_managed_instance`) |
| `filename` | string | Path to the deployment zip on disk |
| `source_code_hash` | string | Base64-encoded SHA256 of the zip |

## Optional inputs

### Function

| Variable | Default | Description |
| --- | --- | --- |
| `description` | `""` | Lambda function description |
| `runtime` | `"python3.14"` | Lambda runtime identifier |
| `handler` | `"lambda_function.lambda_handler"` | Handler in `module.function` format |
| `architectures` | `["x86_64"]` | `["x86_64"]` or `["arm64"]` — must match the capacity provider |
| `memory_size` | `2048` | Memory in MB (LMI minimum: 2048) |
| `timeout` | `30` | Timeout in seconds |
| `ephemeral_storage_size` | `512` | /tmp size in MB (512–10240) |
| `layers` | `[]` | Layer ARNs to attach (max 5) |
| `environment_variables` | `{}` | Runtime environment variables |
| `reserved_concurrent_executions` | `-1` | Concurrency cap; `-1` = unreserved, `0` = throttled |

### Logging

| Variable | Default | Description |
| --- | --- | --- |
| `log_retention_days` | `14` | CloudWatch log group retention in days |
| `cloudwatch_log_group_prevent_destroy` | `false` | When `true`, `lifecycle.prevent_destroy` blocks Terraform from destroying the log group |
| `log_format` | `"JSON"` | `"JSON"` or `"Text"` |
| `application_log_level` | `"INFO"` | App log filter when `log_format = "JSON"` (TRACE/DEBUG/INFO/WARN/ERROR/FATAL) |
| `system_log_level` | `"WARN"` | Platform log filter when `log_format = "JSON"` (DEBUG/INFO/WARN) |

### Concurrency

| Variable | Default | Description |
| --- | --- | --- |
| `per_execution_environment_max_concurrency` | `10` | Concurrent invocations per execution environment — **immutable after first create** |

### IAM

| Variable | Default | Description |
| --- | --- | --- |
| `iam_role_name_prefix` | `"lmi"` | Prefix for the execution role name |
| `additional_execution_policy_arns` | `[]` | Extra managed policy ARNs to attach to the execution role |

### Common

| Variable | Default | Description |
| --- | --- | --- |
| `tags` | `{}` | Tags applied to all taggable resources |

## Key constraints

- **`capacity_provider_config` is immutable** after the function is first created.
- **`per_execution_environment_max_concurrency` is immutable** after the first create.
- **`architectures`** must match the capacity provider's `instance_requirements.architectures`.
- **Minimum `memory_size` is 2048 MB** — enforced by a `validation` block.

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
| `lambda_function_arn` | Unqualified function ARN |
| `lambda_qualified_arn` | Published version ARN (`arn:aws:lambda:...:function:name:version`); use for S3 notifications and other integrations that require a Lambda **function** ARN |
| `lambda_function_name` | Function name |
| `lambda_invoke_arn` | Invoke ARN (unqualified; use for API Gateway HTTP integrations) |
| `lambda_qualified_invoke_arn` | Invoke ARN for the published version (API Gateway style; **not** valid for S3 bucket notifications) |
| `lambda_version` | Published version number |
| `lambda_log_group_name` | CloudWatch log group name |
| `execution_role_arn` | Execution role ARN |
| `execution_role_name` | Execution role name (use to attach additional policies in the calling root) |
