variable "aws_region" {
  description = "AWS region for all resources. Lambda Managed Instances (capacity providers) are only available in a subset of regions; see repository README."
  type        = string
  default     = "ap-southeast-2"
}

variable "name_prefix" {
  description = "Prefix for VPC and Lambda resource names"
  type        = string
  default     = "example"
}

variable "vpc_cidr" {
  description = "VPC IPv4 CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones; the VPC module creates one public and one private subnet per AZ (length must match public_subnet_cidrs and private_subnet_cidrs)"
  type        = list(string)
  default     = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (NAT + IGW path)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs (Lambda managed instances)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# ── WAF ingest ──────────────────────────────────────────────────────────────

variable "waf_logs_bucket_name" {
  description = <<-EOT
    Name of an existing S3 bucket for WAF log objects and the Lambda trigger. This stack does not create the bucket.
    For AWS WAFv2 direct log delivery to S3, the bucket name must start with aws-waf-logs-.
  EOT
  type        = string
}

variable "waf_logs_prefix" {
  description = "Optional S3 key prefix to scope the WAF log trigger (e.g. \"AWSLogs/\"). Empty means all objects in the bucket."
  type        = string
  default     = ""
}

variable "waf_logs_object_suffix" {
  description = "S3 notification filter_suffix (e.g. \".gz\" for WAF delivery). Empty string omits the suffix filter so any object key can trigger the Lambda (useful for uncompressed test uploads; avoid on shared buckets)."
  type        = string
  default     = ".gz"
}

variable "web_acl_arn" {
  description = "ARN of an existing WAFv2 Web ACL. When set, an aws_wafv2_web_acl_logging_configuration resource directs WAF logs to the waf_logs bucket."
  type        = string
  default     = ""
}

# ── Observability stack ──────────────────────────────────────────────────────

variable "alb_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the Grafana ALB on port 80. Leave empty to automatically restrict access to only the deployer's current public IP."
  type        = list(string)
  default     = []
}

variable "obs_instance_type" {
  description = "EC2 instance type for the Loki + Grafana host"
  type        = string
  default     = "t3.small"
}
