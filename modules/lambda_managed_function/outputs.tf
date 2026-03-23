output "lambda_function_arn" {
  description = "ARN of the Lambda function (unqualified)"
  value       = aws_lambda_function.this.arn
}

output "lambda_qualified_arn" {
  description = "ARN of the published function version (use for S3 notifications and other event sources that require a Lambda function ARN, not invoke_arn / qualified_invoke_arn)"
  value       = aws_lambda_function.this.qualified_arn
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.this.function_name
}

output "lambda_qualified_invoke_arn" {
  description = "Invoke ARN for the published version"
  value       = aws_lambda_function.this.qualified_invoke_arn
}

output "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function (unqualified; use for API Gateway HTTP integrations)"
  value       = aws_lambda_function.this.invoke_arn
}

output "lambda_version" {
  description = "Published version number"
  value       = aws_lambda_function.this.version
}

output "lambda_log_group_name" {
  description = "CloudWatch log group name for the Lambda function (use for alarms and dashboards)"
  value       = local.cloudwatch_log_group_name
}

output "execution_role_arn" {
  description = "IAM role ARN used by the function at runtime"
  value       = aws_iam_role.execution.arn
}

output "execution_role_name" {
  description = "IAM role name used by the function at runtime (use to attach additional policies in the calling root)"
  value       = aws_iam_role.execution.name
}
