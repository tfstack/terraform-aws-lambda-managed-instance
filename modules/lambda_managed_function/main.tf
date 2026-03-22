# Inline JSON trust policy avoids aws_iam_policy_document data source,
# which returns invalid output under mock_provider "aws" in terraform test.
locals {
  lambda_assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  # Single logical log group: pick the instance that exists for this deployment.
  cloudwatch_log_group_name = var.cloudwatch_log_group_prevent_destroy ? aws_cloudwatch_log_group.protected[0].name : aws_cloudwatch_log_group.unprotected[0].name
}

# State upgrade: former single resource address (skip if not present in state).
moved {
  from = aws_cloudwatch_log_group.this
  to   = aws_cloudwatch_log_group.unprotected[0]
}

resource "aws_iam_role" "execution" {
  name_prefix        = "${var.iam_role_name_prefix}-exec-"
  description        = "Lambda execution role for ${var.function_name}"
  assume_role_policy = local.lambda_assume_role_policy

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "execution_basic" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Use count (not for_each on ARNs): policy ARNs from other resources are unknown at plan
# time, and toset() would make for_each keys unknowable. Length of the list is known.
resource "aws_iam_role_policy_attachment" "execution_additional" {
  count = length(var.additional_execution_policy_arns)

  role       = aws_iam_role.execution.name
  policy_arn = var.additional_execution_policy_arns[count.index]
}

resource "aws_cloudwatch_log_group" "protected" {
  count = var.cloudwatch_log_group_prevent_destroy ? 1 : 0

  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  lifecycle {
    prevent_destroy = true
  }

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "unprotected" {
  count = var.cloudwatch_log_group_prevent_destroy ? 0 : 1

  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  lifecycle {
    prevent_destroy = false
  }

  tags = var.tags
}

resource "aws_lambda_function" "this" {
  function_name = var.function_name
  description   = var.description
  role          = aws_iam_role.execution.arn
  handler       = var.handler
  runtime       = var.runtime
  architectures = var.architectures

  filename         = var.filename
  source_code_hash = var.source_code_hash

  memory_size                    = var.memory_size
  timeout                        = var.timeout
  publish                        = true
  reserved_concurrent_executions = var.reserved_concurrent_executions

  layers = length(var.layers) > 0 ? var.layers : null

  ephemeral_storage {
    size = var.ephemeral_storage_size
  }

  dynamic "environment" {
    for_each = length(var.environment_variables) > 0 ? [var.environment_variables] : []
    content {
      variables = environment.value
    }
  }

  logging_config {
    log_format            = var.log_format
    log_group             = local.cloudwatch_log_group_name
    application_log_level = var.log_format == "JSON" ? var.application_log_level : null
    system_log_level      = var.log_format == "JSON" ? var.system_log_level : null
  }

  capacity_provider_config {
    lambda_managed_instances_capacity_provider_config {
      capacity_provider_arn                     = var.capacity_provider_arn
      per_execution_environment_max_concurrency = var.per_execution_environment_max_concurrency
    }
  }

  depends_on = [aws_iam_role_policy_attachment.execution_basic]
}
