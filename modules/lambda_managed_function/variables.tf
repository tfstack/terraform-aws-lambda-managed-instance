variable "function_name" {
  description = "Lambda function name"
  type        = string
}

variable "capacity_provider_arn" {
  description = "ARN of the aws_lambda_capacity_provider this function should run on (output of lambda_managed_instance module)"
  type        = string
}

# Deployment artifact — owned by the caller, not the module.
# Use data "archive_file" or filebase64sha256() in the calling root, then pass the results here.

variable "filename" {
  description = "Path to the deployment zip archive on disk"
  type        = string
}

variable "source_code_hash" {
  description = "Base64-encoded SHA256 of the deployment zip (use archive_file output_base64sha256 or filebase64sha256())"
  type        = string
}

variable "runtime" {
  description = "Lambda runtime identifier"
  type        = string
  default     = "python3.14"
}

variable "handler" {
  description = "Lambda handler in module.function format"
  type        = string
  default     = "lambda_function.lambda_handler"
}

variable "architectures" {
  description = "Instruction set architecture — must be [\"x86_64\"] or [\"arm64\"] (single element, must match the capacity provider)"
  type        = list(string)
  default     = ["x86_64"]

  validation {
    condition     = length(var.architectures) == 1 && contains(["x86_64", "arm64"], var.architectures[0])
    error_message = "architectures must be exactly [\"x86_64\"] or [\"arm64\"]."
  }
}

variable "memory_size" {
  description = "Lambda memory in MB. LMI minimum is 2048 (2 GB / 1 vCPU)."
  type        = number
  default     = 2048

  validation {
    condition     = var.memory_size >= 2048
    error_message = "memory_size must be at least 2048 MB (LMI minimum: 2 GB / 1 vCPU)."
  }
}

variable "timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "description" {
  description = "Lambda function description"
  type        = string
  default     = ""
}

variable "ephemeral_storage_size" {
  description = "/tmp ephemeral storage in MB (512–10240). Shared across all concurrent processes in an execution environment — use unique file names per request."
  type        = number
  default     = 512
}

variable "layers" {
  description = "List of Lambda layer ARNs to attach to the function (max 5)"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.layers) <= 5
    error_message = "Lambda supports at most 5 layers per function."
  }
}

variable "environment_variables" {
  description = "Environment variables available to the Lambda function at runtime"
  type        = map(string)
  default     = {}
}

variable "reserved_concurrent_executions" {
  description = "Maximum concurrent executions for this function. -1 means unreserved (default). 0 throttles the function completely."
  type        = number
  default     = -1
}

variable "log_retention_days" {
  description = "CloudWatch log group retention in days"
  type        = number
  default     = 14
}

variable "cloudwatch_log_group_prevent_destroy" {
  description = "When true, the CloudWatch log group uses lifecycle.prevent_destroy so terraform destroy cannot delete it (drop from state or unset to remove). When false, the log group is deleted on destroy. Terraform does not allow variables inside lifecycle blocks, so the module uses two mutually exclusive resource instances."
  type        = bool
  default     = false
}

variable "log_format" {
  description = "CloudWatch log format: \"JSON\" (structured, supports log level filtering) or \"Text\" (plain)"
  type        = string
  default     = "JSON"

  validation {
    condition     = contains(["JSON", "Text"], var.log_format)
    error_message = "log_format must be \"JSON\" or \"Text\"."
  }
}

variable "application_log_level" {
  description = "Application log level filter when log_format is \"JSON\". One of TRACE, DEBUG, INFO, WARN, ERROR, FATAL. Ignored for Text format."
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["TRACE", "DEBUG", "INFO", "WARN", "ERROR", "FATAL"], var.application_log_level)
    error_message = "application_log_level must be one of TRACE, DEBUG, INFO, WARN, ERROR, FATAL."
  }
}

variable "system_log_level" {
  description = "Lambda platform log level filter when log_format is \"JSON\". One of DEBUG, INFO, WARN. Ignored for Text format."
  type        = string
  default     = "WARN"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARN"], var.system_log_level)
    error_message = "system_log_level must be one of DEBUG, INFO, WARN."
  }
}

variable "per_execution_environment_max_concurrency" {
  description = "Max concurrent invocations per execution environment. Immutable after first function create. AWS Python runtime default is 16 per vCPU; lower values reduce memory pressure at the cost of throughput."
  type        = number
  default     = 10
}

variable "iam_role_name_prefix" {
  description = "Prefix for the execution IAM role name"
  type        = string
  default     = "lmi"
}

variable "additional_execution_policy_arns" {
  description = "Additional managed IAM policy ARNs to attach to the Lambda execution role (e.g. for VPC access, S3, or custom permissions)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to all resources in this module"
  type        = map(string)
  default     = {}
}
