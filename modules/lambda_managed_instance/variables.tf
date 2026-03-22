variable "capacity_provider_name" {
  description = "Lambda capacity provider name"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs where managed instances are placed (capacity provider vpc_config)"
  type        = set(string)
}

variable "security_group_ids" {
  description = "Security groups attached to capacity provider managed instances"
  type        = set(string)
}

variable "architectures" {
  description = "Instruction set architecture — must be [\"x86_64\"] or [\"arm64\"] (single element, must match any lambda_managed_function modules using this provider)"
  type        = list(string)
  default     = ["x86_64"]

  validation {
    condition     = length(var.architectures) == 1 && contains(["x86_64", "arm64"], var.architectures[0])
    error_message = "architectures must be exactly [\"x86_64\"] or [\"arm64\"]."
  }
}

variable "max_vcpu_count" {
  description = "Maximum vCPUs for the capacity provider pool"
  type        = number
  default     = 16
}

variable "scaling_mode" {
  description = "Capacity provider scaling mode. Auto: Lambda-managed scaling (no scaling_policies). Manual: optional CPU target via scaling_policies."
  type        = string
  default     = "Auto"

  validation {
    condition     = contains(["Auto", "Manual"], var.scaling_mode)
    error_message = "scaling_mode must be \"Auto\" or \"Manual\"."
  }
}

variable "cpu_target_utilization" {
  description = "When scaling_mode is Manual, target CPU utilisation (0–100) for LambdaCapacityProviderAverageCPUUtilization. Ignored when scaling_mode is Auto."
  type        = number
  default     = 70
}

variable "allowed_instance_types" {
  description = "Allowlist of EC2 instance types for the capacity provider (e.g. [\"m7i.2xlarge\", \"c7i.2xlarge\"]). Mutually exclusive with excluded_instance_types. Leave empty to let Lambda choose."
  type        = list(string)
  default     = []
}

variable "excluded_instance_types" {
  description = "Denylist of EC2 instance types for the capacity provider. Supports wildcards (e.g. [\"*.nano\", \"*.micro\"]). Mutually exclusive with allowed_instance_types. Leave empty to let Lambda choose."
  type        = list(string)
  default     = []
}

variable "iam_role_name_prefix" {
  description = "Prefix for the operator IAM role name"
  type        = string
  default     = "lmi"
}

variable "tags" {
  description = "Tags applied to all resources in this module"
  type        = map(string)
  default     = {}
}
