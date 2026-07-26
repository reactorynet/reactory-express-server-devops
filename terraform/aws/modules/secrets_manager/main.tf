# ---------------------------------------------------------------------------
# module: secrets_manager
#
# The AWS half of secret handling: one Secrets Manager entry per Reactory
# service, plus the IAM role External Secrets Operator assumes to read them.
#
# This lives in the *cluster* layer, alongside the data services that share the
# same credentials, so a password is defined exactly once. The Kubernetes half —
# the operator, the ClusterSecretStore and the ExternalSecret resources — lives
# in modules/external_secrets in the workload layer.
#
# The split exists so the workload layer can configure its kubernetes and helm
# providers from values that are already known at plan time. When cluster and
# workloads share one state, provider configuration depends on resources created
# in the same apply, which makes destroy and cluster replacement unreliable.
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }
}

locals {
  secret_values = {
    mongo      = { username = var.mongo_username, password = var.mongo_password }
    postgres   = { username = var.postgres_username, password = var.postgres_password }
    valkey     = { auth_token = var.valkey_auth_token }
    meili      = { master_key = var.meilisearch_master_key }
    opensearch = { username = var.opensearch_username, password = var.opensearch_password }
    grafana    = { admin_password = var.grafana_admin_password }
    app        = { secret_key = var.app_secret_key }
  }

  # for_each iterates the plain service names, never the value map: Terraform
  # rejects for_each collections derived from sensitive values.
  enabled = toset(var.enabled_secrets)
}

resource "aws_secretsmanager_secret" "reactory" {
  for_each = local.enabled

  name                    = "${var.secret_prefix}/${each.value}"
  description             = "Reactory ${each.value} credentials (${var.secret_prefix})"
  recovery_window_in_days = var.recovery_window_days

  tags = merge(var.tags, {
    Service = each.value
  })
}

resource "aws_secretsmanager_secret_version" "reactory" {
  for_each = local.enabled

  secret_id     = aws_secretsmanager_secret.reactory[each.value].id
  secret_string = jsonencode(local.secret_values[each.value])
}

# ---------------------------------------------------------------------------
# IRSA role for External Secrets Operator
#
# Created here rather than in the workload layer because it is scoped to the
# ARNs of the secrets above. The trust policy is pinned to the operator's
# service account, so only that workload can assume it.
# ---------------------------------------------------------------------------
resource "aws_iam_role" "eso" {
  name        = "${var.cluster_name}-eso-role"
  description = "Assumed by External Secrets Operator to read Reactory secrets"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:${var.eso_namespace}:${var.eso_service_account}"
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "eso_secrets" {
  name        = "${var.cluster_name}-eso-secrets-policy"
  description = "Read-only access to the Reactory secrets in Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecretVersionIds"
      ]
      Resource = [for s in aws_secretsmanager_secret.reactory : s.arn]
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eso" {
  role       = aws_iam_role.eso.name
  policy_arn = aws_iam_policy.eso_secrets.arn
}
