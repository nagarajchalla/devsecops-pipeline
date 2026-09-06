# Demo Terraform module, scanned by Checkov in the pipeline.
#
# This is intentionally a small, self-contained example written from
# scratch for this repository. It provisions nothing real - there are
# no account IDs, ARNs, or environment names from any employer here.

terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "name" {
  description = "Name prefix for created resources"
  type        = string
  default     = "devsecops-demo"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = var.name }
}

# Flow logs are a Checkov requirement (CKV2_AWS_11) and the thing you
# want to already have when investigating an incident.
resource "aws_flow_log" "this" {
  vpc_id          = aws_vpc.this.id
  traffic_type    = "ALL"
  log_destination = aws_cloudwatch_log_group.flow.arn
  iam_role_arn    = aws_iam_role.flow.arn
}

resource "aws_cloudwatch_log_group" "flow" {
  name              = "/aws/vpc/${var.name}"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.logs.arn
}

resource "aws_kms_key" "logs" {
  description             = "CMK for ${var.name} log encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_iam_role" "flow" {
  name = "${var.name}-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Egress-only by default. No 0.0.0.0/0 ingress anywhere in this module -
# open ingress is the single most common Checkov failure in real repos.
resource "aws_security_group" "app" {
  name        = "${var.name}-app"
  description = "Application security group - no public ingress"
  vpc_id      = aws_vpc.this.id

  egress {
    description = "HTTPS to AWS APIs and package registries"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-app" }
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.this.id
}
