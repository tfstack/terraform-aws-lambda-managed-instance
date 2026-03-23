# Custom scaling example

Same **VPC** + **security group** layout as [examples/basic](../basic/), with **`python3.14`** and the split modules:

**`lambda_managed_instance`** (fleet / capacity provider):

- **`scaling_mode = "Manual"`** with a **CPU target** (`cpu_target_utilization`) so the pool tracks average CPU utilisation
- **`allowed_instance_types`** — a pinned allowlist of x86_64 sizes (for example `m7i.2xlarge`, `c7i.4xlarge`) so placement stays predictable

**`lambda_managed_function`** (one function on that provider):

- **`reserved_concurrent_executions`**, **`per_execution_environment_max_concurrency`**, **`environment_variables`**, and structured logging (`log_format`, `application_log_level`)

Defaults use **`lmi-custom`** and **`10.1.0.0/16`** so you can run alongside **basic** (`10.0.0.0/16`) without overlapping CIDRs.

## Apply

```bash
cd examples/custom-scaling
terraform init
terraform plan
terraform apply
```

Optional: add a `terraform.tfvars` file to override variables from `variables.tf` (defaults are set for a non-overlapping CIDR with `examples/basic`).

Tight **allowed** lists can reduce placement flexibility if a type is capacity-constrained in your region — keep at least two sizes in the allowlist where possible.

## Invoke after apply

```bash
aws lambda invoke \
  --function-name "$(terraform output -raw lambda_function_name):$(terraform output -raw lambda_version)" \
  --payload '{"test":true}' \
  --cli-binary-format raw-in-base64-out /tmp/out.json && cat /tmp/out.json
```

## Related examples

- [examples/basic](../basic/) — defaults-only Auto scaling
- [examples/waf-loki](../waf-loki/) — walkthrough networking lab stack

Product reference: [Scaling Lambda Managed Instances](https://docs.aws.amazon.com/lambda/latest/dg/lambda-managed-instances-scaling.html) (instance type selection).
