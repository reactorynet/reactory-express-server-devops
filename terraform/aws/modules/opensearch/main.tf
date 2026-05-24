# ---------------------------------------------------------------------------
# module: opensearch
# Amazon OpenSearch Service domain — replaces Meilisearch in staging/prod.
# Supports two modes via var.mode:
#   "managed"    — standard provisioned OpenSearch domain (staging/prod)
#   "serverless" — OpenSearch Serverless collection (fargate/event-driven)
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50.0"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_security_group" "opensearch" {
  count       = var.mode == "managed" ? 1 : 0
  name        = "${var.cluster_name}-opensearch-sg"
  description = "OpenSearch access from within the VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "OpenSearch HTTPS intra-VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-opensearch-sg"
  })
}

# ---------------------------------------------------------------------------
# Managed OpenSearch domain
# ---------------------------------------------------------------------------
resource "aws_opensearch_domain" "this" {
  count       = var.mode == "managed" ? 1 : 0
  domain_name = "${var.cluster_name}-search"

  engine_version = "OpenSearch_${var.engine_version}"

  cluster_config {
    instance_type          = var.instance_type
    instance_count         = var.instance_count
    zone_awareness_enabled = var.instance_count > 1

    dynamic "zone_awareness_config" {
      for_each = var.instance_count > 1 ? [1] : []
      content {
        availability_zone_count = min(var.instance_count, 2)
      }
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_type = "gp3"
    volume_size = var.volume_size_gb
    throughput  = 125
  }

  vpc_options {
    subnet_ids         = slice(var.private_subnet_ids, 0, min(var.instance_count, length(var.private_subnet_ids)))
    security_group_ids = [aws_security_group.opensearch[0].id]
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    anonymous_auth_enabled         = false
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = var.master_username
      master_user_password = var.master_password
    }
  }

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "*" }
      Action    = "es:*"
      Resource  = "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${var.cluster_name}-search/*"
      Condition = {
        IpAddress = { "aws:SourceIp" = [var.vpc_cidr] }
      }
    }]
  })

  tags = var.tags
}

# ---------------------------------------------------------------------------
# OpenSearch Serverless collection (fargate topology)
# ---------------------------------------------------------------------------
resource "aws_opensearchserverless_security_policy" "encryption" {
  count = var.mode == "serverless" ? 1 : 0
  name  = "${var.cluster_name}-search-enc"
  type  = "encryption"

  policy = jsonencode({
    Rules = [{
      Resource     = ["collection/${var.cluster_name}-search"]
      ResourceType = "collection"
    }]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  count = var.mode == "serverless" ? 1 : 0
  name  = "${var.cluster_name}-search-net"
  type  = "network"

  policy = jsonencode([{
    Rules = [
      { Resource = ["collection/${var.cluster_name}-search"], ResourceType = "collection" },
      { Resource = ["dashboards/default"], ResourceType = "dashboard" }
    ]
    AllowFromPublic = false
    SourceVPCEs     = var.vpce_ids
  }])
}

resource "aws_opensearchserverless_collection" "this" {
  count = var.mode == "serverless" ? 1 : 0
  name  = "${var.cluster_name}-search"
  type  = "SEARCH"

  tags = var.tags

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
  ]
}
