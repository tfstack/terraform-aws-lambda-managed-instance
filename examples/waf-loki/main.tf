provider "aws" {
  region = var.aws_region
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

  tags = merge(
    var.tags,
    { Name = "${var.name_prefix}-lmi" }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Walkthrough reference: every lambda_managed_instance input is explicit below (values match
# module defaults unless noted) so the site can document each argument without inferring defaults.
module "lambda_managed_instance" {
  source = "../../modules/lambda_managed_instance"

  # --- Identity
  capacity_provider_name = "${var.name_prefix}-capacity"
  iam_role_name_prefix   = var.name_prefix # walkthrough: use name_prefix; module default is "lmi"

  # --- Capacity provider and scaling
  max_vcpu_count         = 16
  scaling_mode           = "Auto"
  cpu_target_utilization = 70 # used when scaling_mode = "Manual"; ignored for Auto

  allowed_instance_types  = [] # mutually exclusive with excluded_instance_types
  excluded_instance_types = []

  # --- VPC placement (capacity provider)
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [aws_security_group.lmi.id]

  tags = var.tags
}

# ── Data sources (shared by WAF + observability sections) ───────────────────

data "http" "my_public_ip" {
  url = "https://checkip.amazonaws.com/"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

locals {
  my_public_ip_cidr = "${trimspace(data.http.my_public_ip.response_body)}/32"
  alb_ingress_cidrs = length(var.alb_ingress_cidrs) > 0 ? var.alb_ingress_cidrs : [local.my_public_ip_cidr]
  loki_push_url     = "http://${aws_instance.obs.private_ip}:3100/loki/api/v1/push"
}

# ── WAF log bucket (existing; not managed by this stack) ─────────────────────
# Terraform only reads the bucket for IAM, notifications, and optional WAF logging.
# Create and secure the bucket outside this configuration.

data "aws_s3_bucket" "waf_logs" {
  bucket = var.waf_logs_bucket_name
}

# ── IAM: WAF Lambda S3 read ──────────────────────────────────────────────────

resource "aws_iam_policy" "waf_s3_read" {
  name_prefix = "${var.name_prefix}-waf-s3-"
  description = "Allow WAF ingest Lambda to read objects from the WAF log bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${data.aws_s3_bucket.waf_logs.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = data.aws_s3_bucket.waf_logs.arn
      }
    ]
  })
}

# ── WAF ingest Lambda (Node.js 24) ───────────────────────────────────────────

data "archive_file" "waf_zip" {
  type        = "zip"
  source_dir  = "${path.module}/function-waf"
  output_path = "${path.module}/.build/waf.zip"
  # Runtime ships AWS SDK v3; local node_modules (if present) must not inflate the artifact.
  excludes = ["node_modules/**"]
}

module "lambda_managed_function_waf" {
  source = "../../modules/lambda_managed_function"

  # --- Identity
  function_name         = "${var.name_prefix}-waf-fn"
  capacity_provider_arn = module.lambda_managed_instance.capacity_provider_arn
  iam_role_name_prefix  = "${var.name_prefix}-waf"
  description           = "WAF S3 log ingest - reads gzip WAF log objects and pushes to Loki"

  # --- Deployment artifact
  filename         = data.archive_file.waf_zip.output_path
  source_code_hash = data.archive_file.waf_zip.output_base64sha256

  # --- Function
  runtime       = "nodejs24.x"
  handler       = "index.handler"
  architectures = ["x86_64"]

  memory_size            = 2048
  timeout                = 60
  ephemeral_storage_size = 512

  layers                         = []
  environment_variables          = { LOKI_URL = local.loki_push_url }
  reserved_concurrent_executions = -1

  # --- Logging
  log_retention_days                   = 14
  cloudwatch_log_group_prevent_destroy = false
  log_format                           = "JSON"
  application_log_level                = "INFO"
  system_log_level                     = "WARN"

  # --- Concurrency
  per_execution_environment_max_concurrency = 10

  # --- IAM: add S3 read for waf_logs bucket
  additional_execution_policy_arns = [aws_iam_policy.waf_s3_read.arn]

  tags = var.tags
}

resource "aws_lambda_permission" "s3_invoke_waf" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_managed_function_waf.lambda_function_name
  qualifier     = module.lambda_managed_function_waf.lambda_version
  principal     = "s3.amazonaws.com"
  source_arn    = data.aws_s3_bucket.waf_logs.arn
}

resource "aws_s3_bucket_notification" "waf_logs" {
  bucket = data.aws_s3_bucket.waf_logs.id

  lambda_function {
    # S3 requires arn:aws:lambda:...:function:name[:version]; not qualified_invoke_arn (API Gateway style).
    lambda_function_arn = module.lambda_managed_function_waf.lambda_qualified_arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.waf_logs_prefix != "" ? var.waf_logs_prefix : null
    filter_suffix       = var.waf_logs_object_suffix != "" ? var.waf_logs_object_suffix : null
  }

  depends_on = [aws_lambda_permission.s3_invoke_waf]
}

# ── Optional: WAFv2 logging configuration ────────────────────────────────────
# Set var.web_acl_arn to an existing WAFv2 Web ACL ARN to enable WAF log delivery.

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.web_acl_arn != "" ? 1 : 0

  resource_arn            = var.web_acl_arn
  log_destination_configs = [data.aws_s3_bucket.waf_logs.arn]
}

# ── Observability: security groups ───────────────────────────────────────────

resource "aws_security_group" "alb" {
  name_prefix = "${var.name_prefix}-alb-"
  description = "Grafana ALB - HTTP ingress from allowed CIDRs"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = local.alb_ingress_cidrs
    description = "HTTP from allowed CIDRs"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-alb" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "obs" {
  name_prefix = "${var.name_prefix}-obs-"
  description = "Loki + Grafana EC2 host"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3100
    to_port         = 3100
    protocol        = "tcp"
    security_groups = [aws_security_group.lmi.id]
    description     = "Loki push from Lambda ENIs"
  }

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Grafana from ALB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-obs" })

  lifecycle {
    create_before_destroy = true
  }
}

# ── Observability: EC2 instance profile (SSM access, no SSH key required) ───

data "aws_iam_policy_document" "obs_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "obs_ec2" {
  name_prefix        = "${var.name_prefix}-obs-"
  assume_role_policy = data.aws_iam_policy_document.obs_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "obs_ssm" {
  role       = aws_iam_role.obs_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "obs_ec2" {
  name_prefix = "${var.name_prefix}-obs-"
  role        = aws_iam_role.obs_ec2.name
  tags        = var.tags
}

# ── Observability: EC2 instance (private subnet, EBS-backed Loki data) ───────

resource "aws_instance" "obs" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.obs_instance_type
  subnet_id              = module.vpc.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.obs.id]
  iam_instance_profile   = aws_iam_instance_profile.obs_ec2.name

  user_data = templatefile("${path.module}/templates/user_data.sh.tftpl", {
    waf_dashboard_b64 = filebase64("${path.module}/templates/dashboards/waf.json")
    waf_overview_b64  = filebase64("${path.module}/templates/dashboards/waf-overview.json")
  })
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-obs" })
}

# ── Observability: Application Load Balancer (Grafana) ───────────────────────

resource "aws_lb" "grafana" {
  name                       = "${var.name_prefix}-grafana"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = module.vpc.public_subnet_ids
  drop_invalid_header_fields = true

  tags = merge(var.tags, { Name = "${var.name_prefix}-grafana" })
}

resource "aws_lb_target_group" "grafana" {
  name        = "${var.name_prefix}-grafana"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    protocol            = "HTTP"
    path                = "/api/health"
    port                = "traffic-port"
    matcher             = "200"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-grafana" })
}

resource "aws_lb_listener" "grafana" {
  load_balancer_arn = aws_lb.grafana.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
}

resource "aws_lb_target_group_attachment" "grafana" {
  target_group_arn = aws_lb_target_group.grafana.arn
  target_id        = aws_instance.obs.id
  port             = 3000
}
