# ---------------------------------------------------------------------------
# module: secrets
# Creates AWS Secrets Manager secrets for all Reactory services and
# installs the External Secrets Operator (ESO) via Helm so Kubernetes
# can pull them as native Secrets.
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.17.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Secrets Manager secrets
# ---------------------------------------------------------------------------
locals {
  secrets = {
    mongo    = { username = var.mongo_username, password = var.mongo_password }
    postgres = { username = var.postgres_username, password = var.postgres_password }
    valkey   = { auth_token = var.valkey_auth_token }
    meili    = { master_key = var.meilisearch_master_key }
    opensearch = { username = var.opensearch_username, password = var.opensearch_password }
    grafana  = { admin_password = var.grafana_admin_password }
    app      = { secret_key = var.app_secret_key }
  }
}

resource "aws_secretsmanager_secret" "reactory" {
  for_each = local.secrets

  name                    = "${var.secret_prefix}/${each.key}"
  recovery_window_in_days = var.recovery_window_days

  tags = merge(var.tags, {
    Service = each.key
  })
}

resource "aws_secretsmanager_secret_version" "reactory" {
  for_each = local.secrets

  secret_id     = aws_secretsmanager_secret.reactory[each.key].id
  secret_string = jsonencode(each.value)
}

# ---------------------------------------------------------------------------
# IRSA role for External Secrets Operator
# ---------------------------------------------------------------------------
resource "aws_iam_role" "eso" {
  name = "${var.cluster_name}-eso-role"

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
          "${var.oidc_provider_url}:sub" = "system:serviceaccount:external-secrets:external-secrets"
          "${var.oidc_provider_url}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "eso_secrets" {
  name        = "${var.cluster_name}-eso-secrets-policy"
  description = "Allow ESO to read Reactory secrets from Secrets Manager"

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
}

resource "aws_iam_role_policy_attachment" "eso" {
  role       = aws_iam_role.eso.name
  policy_arn = aws_iam_policy.eso_secrets.arn
}

# ---------------------------------------------------------------------------
# External Secrets Operator (Helm)
# ---------------------------------------------------------------------------
resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = "external-secrets"
  }
}

resource "helm_release" "eso" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.eso_chart_version
  namespace  = kubernetes_namespace.external_secrets.metadata[0].name

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.eso.arn
  }

  depends_on = [kubernetes_namespace.external_secrets]
}

# ClusterSecretStore — points ESO to Secrets Manager in the cluster's region
resource "kubernetes_manifest" "cluster_secret_store" {
  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = "aws-secrets-manager"
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = "external-secrets"
                namespace = "external-secrets"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.eso]
}
