# -----------------------------------------------------------------------------
# AWS application host: EC2 + S3 + Security Groups + IAM
#
# Provisions one environment (dev / uat / prod) of the API:
#   - EC2 instance (Ubuntu 24.04) with an Elastic IP, IMDSv2 and an encrypted root disk
#   - Security group: HTTP/HTTPS public, SSH only from admin CIDRs
#   - S3 bucket for artifacts and backups (private, versioned, encrypted)
#   - IAM role and instance profile: the EC2 instance reaches only its own bucket, plus SSM
#
# Usage:
#   terraform init
#   terraform plan  -var-file=env/dev.tfvars
#   terraform apply -var-file=env/dev.tfvars
#
# After apply, configure the server with Ansible (see ../ansible).
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state with S3-native locking (Terraform >= 1.10).
  # Uncomment and set the bucket before using this in a team.
  # backend "s3" {
  #   bucket       = "my-terraform-state-bucket"
  #   key          = "api/dev/terraform.tfstate"
  #   region       = "ap-south-1"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# =============================================================================
# Variables
# =============================================================================

variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Project name, used as a prefix for every resource name"
  type        = string
  default     = "api"

  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", var.project))
    error_message = "project must be 2-20 characters: lowercase letters, digits and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "uat", "prod"], var.environment)
    error_message = "environment must be one of: dev, uat, prod."
  }
}

variable "vpc_id" {
  description = "VPC to deploy into"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet for the instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GiB"
  type        = number
  default     = 20
}

variable "key_name" {
  description = "Existing EC2 key pair for SSH (null = SSM Session Manager only)"
  type        = string
  default     = null
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed to SSH to the instance (office / VPN IPs)"
  type        = list(string)
  default     = []

  validation {
    condition     = !contains(var.admin_cidr_blocks, "0.0.0.0/0")
    error_message = "Do not open SSH to the whole internet; use specific CIDRs or SSM."
  }
}

variable "artifact_retention_days" {
  description = "Days to keep non-current object versions in the S3 bucket"
  type        = number
  default     = 30
}

# =============================================================================
# Data sources
# =============================================================================

data "aws_caller_identity" "current" {}

# Latest official Canonical Ubuntu 24.04 LTS image
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  name_prefix = "${var.project}-${var.environment}"
  # S3 bucket names are global, so add the account ID to keep this one unique
  bucket_name = "${local.name_prefix}-artifacts-${data.aws_caller_identity.current.account_id}"
}

# =============================================================================
# Security group
# =============================================================================

resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "API host: public HTTP/HTTPS, restricted SSH"
  vpc_id      = var.vpc_id

  tags = { Name = "${local.name_prefix}-app-sg" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = toset(var.admin_cidr_blocks)

  security_group_id = aws_security_group.app.id
  description       = "SSH from admin network"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound (package updates, S3, SSM)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# =============================================================================
# S3: artifacts and backups bucket
# =============================================================================

resource "aws_s3_bucket" "artifacts" {
  bucket = local.bucket_name

  # Stop an accidental `terraform destroy` from deleting production data
  force_destroy = var.environment != "prod"
}

resource "aws_s3_bucket_ownership_controls" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.artifact_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.artifacts]
}

# Refuse any request that isn't over TLS
resource "aws_s3_bucket_policy" "artifacts_tls_only" {
  bucket = aws_s3_bucket.artifacts.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource = [
        aws_s3_bucket.artifacts.arn,
        "${aws_s3_bucket.artifacts.arn}/*",
      ]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.artifacts]
}

# =============================================================================
# IAM: instance role (least privilege)
# =============================================================================

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "app" {
  name               = "${local.name_prefix}-app-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

# Access to this environment's bucket only. No s3:* and no wildcard buckets.
data "aws_iam_policy_document" "artifacts_access" {
  statement {
    sid       = "ListBucket"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.artifacts.arn]
  }

  statement {
    sid       = "ReadWriteObjects"
    actions   = ["s3:GetObject", "s3:PutObject"]
    resources = ["${aws_s3_bucket.artifacts.arn}/*"]
  }
}

resource "aws_iam_role_policy" "artifacts_access" {
  name   = "artifacts-bucket-access"
  role   = aws_iam_role.app.id
  policy = data.aws_iam_policy_document.artifacts_access.json
}

# SSM Session Manager: shell access without opening port 22
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app" {
  name = "${local.name_prefix}-app-profile"
  role = aws_iam_role.app.name
}

# =============================================================================
# EC2 instance
# =============================================================================

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.app.name
  key_name               = var.key_name
  monitoring             = var.environment == "prod"

  # IMDSv2 only: blocks SSRF-style credential theft through the metadata endpoint
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  # Minimal bootstrap. Ansible handles the full configuration.
  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    hostnamectl set-hostname ${local.name_prefix}-app
    apt-get update -y
    apt-get install -y python3 python3-apt
  EOF

  tags = { Name = "${local.name_prefix}-app" }

  lifecycle {
    # A newer AMI must not force an instance replacement on a routine plan
    ignore_changes = [ami, user_data]
  }
}

# Static public IP that stays the same across stop/start (used for DNS and the Ansible inventory)
resource "aws_eip" "app" {
  domain   = "vpc"
  instance = aws_instance.app.id
  tags     = { Name = "${local.name_prefix}-app-eip" }
}

# =============================================================================
# Outputs
# =============================================================================

output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.app.id
}

output "public_ip" {
  description = "Elastic IP of the application server"
  value       = aws_eip.app.public_ip
}

output "private_ip" {
  description = "Private IP of the application server"
  value       = aws_instance.app.private_ip
}

output "security_group_id" {
  description = "Security group attached to the instance"
  value       = aws_security_group.app.id
}

output "artifacts_bucket" {
  description = "S3 bucket for artifacts and backups"
  value       = aws_s3_bucket.artifacts.bucket
}

output "instance_role_arn" {
  description = "IAM role assumed by the instance"
  value       = aws_iam_role.app.arn
}

output "ssm_connect_command" {
  description = "Open a shell on the instance without SSH"
  value       = "aws ssm start-session --target ${aws_instance.app.id} --region ${var.aws_region}"
}

output "ansible_inventory_line" {
  description = "Paste into ansible/inventory.ini under the matching environment group"
  value       = "${local.name_prefix}-app ansible_host=${aws_eip.app.public_ip}"
}
