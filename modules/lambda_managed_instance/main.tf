# The first capacity provider in an account triggers automatic SLR creation (for ec2:TerminateInstances).
# If the SLR already exists in the account, this resource will fail on create with "already exists".
# In that case, import the existing role before running plan:
#   terraform import aws_iam_service_linked_role.lambda_lmi \
#     arn:aws:iam::<ACCOUNT_ID>:role/aws-service-role/lambda.amazonaws.com/AWSServiceRoleForLambda
resource "aws_iam_service_linked_role" "lambda_lmi" {
  aws_service_name = "lambda.amazonaws.com"
  description      = "Service-linked role for Lambda Managed Instances fleet lifecycle operations"
}

resource "aws_iam_role" "operator" {
  name_prefix = "${var.iam_role_name_prefix}-op-"
  description = "Lambda operator role for capacity provider ${var.capacity_provider_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "operator_managed" {
  role       = aws_iam_role.operator.name
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaManagedEC2ResourceOperator"
}

resource "aws_lambda_capacity_provider" "this" {
  name = var.capacity_provider_name

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  permissions_config {
    capacity_provider_operator_role_arn = aws_iam_role.operator.arn
  }

  instance_requirements {
    architectures           = var.architectures
    allowed_instance_types  = length(var.allowed_instance_types) > 0 ? var.allowed_instance_types : null
    excluded_instance_types = length(var.excluded_instance_types) > 0 ? var.excluded_instance_types : null
  }

  dynamic "capacity_provider_scaling_config" {
    for_each = {
      _ = {
        mode     = var.scaling_mode
        max_vcpu = var.max_vcpu_count
        cpu      = var.cpu_target_utilization
      }
    }
    content {
      scaling_mode   = capacity_provider_scaling_config.value.mode
      max_vcpu_count = capacity_provider_scaling_config.value.max_vcpu
      dynamic "scaling_policies" {
        for_each = capacity_provider_scaling_config.value.mode == "Manual" ? [capacity_provider_scaling_config.value.cpu] : []
        content {
          predefined_metric_type = "LambdaCapacityProviderAverageCPUUtilization"
          target_value           = scaling_policies.value
        }
      }
    }
  }

  tags = var.tags

  depends_on = [
    aws_iam_service_linked_role.lambda_lmi,
    aws_iam_role_policy_attachment.operator_managed,
  ]
}
