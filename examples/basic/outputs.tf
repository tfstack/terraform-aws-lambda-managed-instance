output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "capacity_provider_name" {
  value = module.lambda_managed_instance.capacity_provider_name
}

output "lambda_function_name" {
  value = module.lambda_managed_function.lambda_function_name
}

output "lambda_qualified_invoke_arn" {
  description = "Use this ARN with aws lambda invoke (published version)"
  value       = module.lambda_managed_function.lambda_qualified_invoke_arn
}

output "lambda_version" {
  description = "Published Lambda version (use with function_name for invoke)"
  value       = module.lambda_managed_function.lambda_version
}

output "lambda_log_group_name" {
  description = "CloudWatch log group; tail logs or set alarms here"
  value       = module.lambda_managed_function.lambda_log_group_name
}
