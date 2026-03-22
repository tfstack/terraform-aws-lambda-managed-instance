output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "capacity_provider_name" {
  value = module.lambda_managed_instance.capacity_provider_name
}

# ── WAF ingest Lambda ────────────────────────────────────────────────────────

output "waf_function_name" {
  description = "WAF ingest Lambda function name"
  value       = module.lambda_managed_function_waf.lambda_function_name
}

output "waf_function_version" {
  description = "Published WAF ingest Lambda version"
  value       = module.lambda_managed_function_waf.lambda_version
}

output "waf_log_group_name" {
  description = "CloudWatch log group for the WAF ingest Lambda"
  value       = module.lambda_managed_function_waf.lambda_log_group_name
}

output "waf_logs_bucket" {
  description = "Existing S3 bucket name wired for WAF log delivery and Lambda trigger"
  value       = data.aws_s3_bucket.waf_logs.id
}

# ── Observability ────────────────────────────────────────────────────────────

output "grafana_url" {
  description = "Grafana URL via the public ALB - open in browser (admin / admin)"
  value       = "http://${aws_lb.grafana.dns_name}"
}

output "loki_push_url" {
  description = "Loki push API endpoint used by the WAF ingest Lambda"
  value       = local.loki_push_url
}

output "obs_instance_id" {
  description = "EC2 instance ID of the Loki + Grafana host (connect via SSM Session Manager)"
  value       = aws_instance.obs.id
}
