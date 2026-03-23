provider "aws" {
  region = var.aws_region
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/function"
  output_path = "${path.module}/.build/lambda.zip"
}

module "vpc" {
  source = "../../modules/vpc"

  vpc_name             = "${var.name_prefix}-vpc"
  vpc_cidr             = var.vpc_cidr
  tags                 = var.tags
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

resource "aws_security_group" "lmi" {
  name_prefix = "${var.name_prefix}-lmi-"
  description = "Lambda Managed Instances capacity provider ENIs; egress for CloudWatch Logs and Lambda control plane"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-lmi" })

  lifecycle {
    create_before_destroy = true
  }
}

# Manual scaling with a pinned set of compute-optimised x86_64 instance types.
# Lambda will only place managed instances on types in the allowlist, giving you
# predictable CPU-to-memory ratios for CPU-bound workloads. The CPU target policy
# scales the pool in/out to maintain 60 % average utilisation.
module "lambda_managed_instance" {
  source = "../../modules/lambda_managed_instance"

  capacity_provider_name = "${var.name_prefix}-capacity"
  iam_role_name_prefix   = var.name_prefix

  # x86_64 compute-optimised instances — balanced CPU/memory for CPU-bound tasks.
  # Specify at least two sizes so Lambda has flexibility when a type is constrained.
  architectures          = ["x86_64"]
  allowed_instance_types = ["m7i.2xlarge", "m7i.4xlarge", "c7i.2xlarge", "c7i.4xlarge"]

  # Manual mode: the pool scales to maintain cpu_target_utilization across all instances.
  scaling_mode           = "Manual"
  cpu_target_utilization = 60
  max_vcpu_count         = 64

  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [aws_security_group.lmi.id]

  tags = var.tags
}

module "lambda_managed_function" {
  source = "../../modules/lambda_managed_function"

  function_name         = "${var.name_prefix}-fn"
  capacity_provider_arn = module.lambda_managed_instance.capacity_provider_arn
  iam_role_name_prefix  = var.name_prefix
  description           = "Example Lambda Managed Instance — manual scaling with specific instance types"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  runtime                = "python3.14"
  architectures          = ["x86_64"]
  memory_size            = 4096
  timeout                = 60
  ephemeral_storage_size = 1024

  # Cap concurrent invocations to prevent runaway spend if traffic spikes unexpectedly.
  reserved_concurrent_executions = 50

  # Each execution environment handles up to 8 concurrent requests before Lambda
  # places additional requests on a new environment. Lower than the default (10)
  # to reduce head-of-line blocking for this CPU-bound workload.
  per_execution_environment_max_concurrency = 8

  environment_variables = {
    ENV       = "production"
    LOG_LEVEL = "INFO"
  }

  # JSON structured logging with DEBUG-level app output for detailed tracing.
  log_format            = "JSON"
  application_log_level = "DEBUG"
  system_log_level      = "INFO"
  log_retention_days    = 30

  tags = var.tags
}
