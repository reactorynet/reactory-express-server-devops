# ---------------------------------------------------------------------------
# module: elasticache_valkey
# Amazon ElastiCache for Valkey (drop-in Redis replacement).
# Supports three modes via var.mode:
#   "single"     — single node, no replication (dev)
#   "cluster"    — cluster mode enabled, multi-shard, multi-AZ (production)
#   "serverless" — ElastiCache Serverless (auto-scaling, no capacity planning)
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50.0"
    }
  }
}

resource "aws_elasticache_subnet_group" "this" {
  count      = var.mode != "serverless" ? 1 : 0
  name       = "${var.cluster_name}-valkey-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-valkey-subnet-group"
  })
}

resource "aws_security_group" "valkey" {
  name        = "${var.cluster_name}-valkey-sg"
  description = "Valkey/Redis access from within the VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Valkey intra-VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-valkey-sg"
  })
}

# ---------------------------------------------------------------------------
# Single-node replication group (dev / staging without cluster mode)
# ---------------------------------------------------------------------------
resource "aws_elasticache_replication_group" "this" {
  count = var.mode != "serverless" ? 1 : 0

  replication_group_id = "${var.cluster_name}-valkey"
  description          = "Reactory Valkey cache"
  engine               = "valkey"
  engine_version       = var.engine_version
  node_type            = var.node_type
  port                 = 6379

  # Cluster mode
  num_node_groups         = var.mode == "cluster" ? var.num_shards : 1
  replicas_per_node_group = var.mode == "cluster" ? var.replicas_per_shard : (var.multi_az ? 1 : 0)

  automatic_failover_enabled = var.mode == "cluster" || var.multi_az
  multi_az_enabled           = var.multi_az

  subnet_group_name  = aws_elasticache_subnet_group.this[0].name
  security_group_ids = [aws_security_group.valkey.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.auth_token

  maintenance_window       = "sun:05:00-sun:06:00"
  snapshot_retention_limit = var.snapshot_retention_days
  snapshot_window          = "03:00-04:00"

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Serverless cache (auto-scaling, us-west-1 supported)
# ---------------------------------------------------------------------------
resource "aws_elasticache_serverless_cache" "this" {
  count = var.mode == "serverless" ? 1 : 0

  name   = "${var.cluster_name}-valkey-serverless"
  engine = "valkey"

  cache_usage_limits {
    data_storage {
      maximum = var.serverless_max_storage_gb
      unit    = "GB"
    }
    ecpu_per_second {
      maximum = var.serverless_max_ecpu
    }
  }

  subnet_ids         = var.private_subnet_ids
  security_group_ids = [aws_security_group.valkey.id]

  tags = var.tags
}
