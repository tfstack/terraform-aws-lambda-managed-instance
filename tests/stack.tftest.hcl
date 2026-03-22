# Terraform native tests (terraform test). AWS and archive providers are mocked so
# plans run without credentials or real zip files on disk.
# Requires Terraform >= 1.7.

mock_provider "aws" {}

mock_provider "archive" {
  mock_data "archive_file" {
    defaults = {
      output_path             = "/tmp/mock-lambda.zip"
      output_base64sha256     = "bW9ja2hhc2g="
      output_md5              = "mockhash"
      output_sha              = "mockhash"
      output_sha256           = "mockhash"
      output_sha512           = "mockhash"
      output_size             = 1024
      source_content_filename = null
    }
  }
}

run "root_stack_plan" {
  command = plan

  variables {
    name_prefix          = "tftest-lmi"
    aws_region           = "ap-southeast-2"
    vpc_cidr             = "10.99.0.0/16"
    availability_zones   = ["ap-southeast-2a", "ap-southeast-2b"]
    public_subnet_cidrs  = ["10.99.0.0/24", "10.99.1.0/24"]
    private_subnet_cidrs = ["10.99.8.0/24", "10.99.9.0/24"]
    tags = {
      Test = "terraform-test"
    }
  }

  assert {
    condition     = length(var.private_subnet_cidrs) == 2 && length(var.public_subnet_cidrs) == 2
    error_message = "test variables must define two public and two private subnets"
  }

  assert {
    condition     = module.lambda_managed_function.lambda_function_name == "tftest-lmi-fn"
    error_message = "lambda function name must follow name_prefix pattern"
  }

  assert {
    condition     = module.lambda_managed_instance.capacity_provider_name == "tftest-lmi-capacity"
    error_message = "capacity provider name must follow name_prefix pattern"
  }

  assert {
    condition     = module.lambda_managed_function.lambda_log_group_name == "/aws/lambda/tftest-lmi-fn"
    error_message = "log group name must be /aws/lambda/<function_name>"
  }
}
