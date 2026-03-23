output "capacity_provider_arn" {
  description = "ARN of the Lambda capacity provider"
  value       = aws_lambda_capacity_provider.this.arn
}

output "capacity_provider_name" {
  description = "Name of the Lambda capacity provider"
  value       = aws_lambda_capacity_provider.this.name
}

output "operator_role_arn" {
  description = "IAM role ARN Lambda uses to manage EC2 for the capacity provider"
  value       = aws_iam_role.operator.arn
}
