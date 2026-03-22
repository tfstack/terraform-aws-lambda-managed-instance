provider "aws" {
  region = var.aws_region
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/function"
  output_path = "${path.module}/.build/lambda.zip"
}

module "vpc" {
  source = "../../modules/vpc"

  vpc_name             = "${var.name_prefix}-vpc"
  vpc_cidr             = var.vpc_cidr
  tags                 = var.tags
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

resource "aws_security_group" "lmi" {
  name_prefix = "${var.name_prefix}-lmi-"
  description = "Lambda Managed Instances capacity provider ENIs; egress for CloudWatch Logs and Lambda control plane"
  vpc_id      = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-lmi" })

  lifecycle {
    create_before_destroy = true
  }
}

module "lambda_managed_instance" {
  source = "../../modules/lambda_managed_instance"

  capacity_provider_name = "${var.name_prefix}-capacity"
  iam_role_name_prefix   = var.name_prefix

  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [aws_security_group.lmi.id]

  tags = var.tags
}

module "lambda_managed_function" {
  source = "../../modules/lambda_managed_function"

  function_name         = "${var.name_prefix}-fn"
  capacity_provider_arn = module.lambda_managed_instance.capacity_provider_arn
  iam_role_name_prefix  = var.name_prefix
  description           = "Example Lambda Managed Instance function"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  runtime = "python3.14"

  tags = var.tags
}
