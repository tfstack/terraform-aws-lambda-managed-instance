# Basic example

Minimal **VPC** (`modules/vpc`) + **security group** + two modules:

- **`lambda_managed_instance`** — capacity provider, operator role, and service-linked role wiring
- **`lambda_managed_function`** — execution role, CloudWatch log group, and **`python3.14`** sample function (via **`capacity_provider_arn`** from the first module)

Same shape as the **repository root** stack, but with its own working directory and state file.

Defaults use **`lmi-basic`** and **`10.0.0.0/16`** (two AZs). Use a different `vpc_cidr` / `name_prefix` in `terraform.tfvars` if you deploy multiple examples in one account and region.

## Apply

```bash
cd examples/basic
terraform init
terraform plan
terraform apply
```

Optional: add a `terraform.tfvars` file to override `aws_region`, `vpc_cidr`, `name_prefix`, or other variables from `variables.tf`.

## Invoke after apply

```bash
aws lambda invoke \
  --function-name "$(terraform output -raw lambda_function_name):$(terraform output -raw lambda_version)" \
  --payload '{"test":true}' \
  --cli-binary-format raw-in-base64-out /tmp/out.json && cat /tmp/out.json
```

First apply can take several minutes while capacity and the published version become active.

## Related examples

- [examples/custom-scaling](../custom-scaling/) — manual scaling and allowed instance types
- [examples/waf-loki](../waf-loki/) — walkthrough demo base (three AZs by default)

Walkthrough site: [aws-lambda-managed-instance-walkthrough](https://github.com/jajera/aws-lambda-managed-instance-walkthrough).
