# ─────────────────────────────────────────────────────────────────────────────
# SecurePipe — Terraform IaC
# Checkov scans this file for misconfigurations in the pipeline.
# ─────────────────────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state — never use local state in production
  backend "s3" {
    bucket  = "securepipe-tfstate"
    key     = "securepipe/terraform.tfstate"
    region  = "ap-south-1"
    encrypt = true  # CKV_AWS_119 — S3 backend encryption
  }
}

provider "aws" {
  region = var.aws_region
}

# ─── Variables ───────────────────────────────────────────────────────────────
variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
  default     = "prod"
}

variable "app_port" {
  description = "Port the app listens on"
  type        = number
  default     = 5000
}

# ─── VPC ─────────────────────────────────────────────────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "securepipe-vpc"
    Environment = var.environment
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"

  # CKV_AWS_130 — no public IP assigned on launch
  map_public_ip_on_launch = false

  tags = {
    Name        = "securepipe-private-subnet"
    Environment = var.environment
  }
}

# ─── Security Group ──────────────────────────────────────────────────────────
resource "aws_security_group" "app" {
  name        = "securepipe-sg"
  description = "Security group for SecurePipe application"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "App port from VPC only"
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # CKV_AWS_25 — NOT 0.0.0.0/0
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "securepipe-sg"
    Environment = var.environment
  }
}

# ─── S3 Bucket (Hardened) ────────────────────────────────────────────────────
resource "aws_s3_bucket" "app_artifacts" {
  bucket = "securepipe-artifacts-${var.environment}"

  tags = {
    Name        = "securepipe-artifacts"
    Environment = var.environment
  }
}

# CKV_AWS_19 — S3 encryption at rest
resource "aws_s3_bucket_server_side_encryption_configuration" "app_artifacts" {
  bucket = aws_s3_bucket.app_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CKV_AWS_57 — Block all public access
resource "aws_s3_bucket_public_access_block" "app_artifacts" {
  bucket = aws_s3_bucket.app_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CKV_AWS_21 — Enable versioning
resource "aws_s3_bucket_versioning" "app_artifacts" {
  bucket = aws_s3_bucket.app_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# CKV_AWS_144 — Enable cross-region replication (optional — commented for demo)
# resource "aws_s3_bucket_replication_configuration" "app_artifacts" { ... }

# ─── EC2 (Hardened) ──────────────────────────────────────────────────────────
resource "aws_instance" "app" {
  ami           = "ami-0f58b397bc5c1f2e8"  # Ubuntu 24.04 ap-south-1
  instance_type = "t3.micro"
  subnet_id     = aws_subnet.private.id

  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = false  # CKV_AWS_8

  # CKV_AWS_8 — EBS encryption
  root_block_device {
    encrypted   = true
    volume_size = 20
    volume_type = "gp3"
  }

  # CKV_AWS_135 — IMDSv2 only
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"   # IMDSv2
    http_put_response_hop_limit = 1
  }

  # CKV_AWS_126 — Detailed monitoring
  monitoring = true

  tags = {
    Name        = "securepipe-app"
    Environment = var.environment
  }
}

# ─── IAM Role (Least Privilege) ──────────────────────────────────────────────
resource "aws_iam_role" "app" {
  name = "securepipe-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Environment = var.environment
  }
}

# CKV_AWS_40 — Attach policy, not inline admin
resource "aws_iam_role_policy" "app_s3" {
  name = "securepipe-s3-access"
  role = aws_iam_role.app.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:PutObject"]
      Resource = "${aws_s3_bucket.app_artifacts.arn}/*"
    }]
  })
}

# ─── Outputs ─────────────────────────────────────────────────────────────────
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.app_artifacts.bucket
  description = "Artifacts S3 bucket name"
}
