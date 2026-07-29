# ---------------------------------------------------------------------------
# module: app_secrets
#
# Creates the Kubernetes Secrets the Reactory workloads read, directly from
# Terraform variables.
#
# This is the DigitalOcean and Linode path. Neither provider has a secrets
# manager, so there is nothing for External Secrets Operator to point at; the
# AWS blueprints keep secrets_manager + external_secrets instead.
#
# ---------------------------------------------------------------------------
# SECURITY NOTE — READ BEFORE USING THIS IN PRODUCTION
#
# Every value below is stored in plaintext in the Terraform state file. The
# state bucket is therefore a secrets store and must be treated as one:
#   - private bucket, no public access
#   - encryption at rest enabled
#   - access restricted to the people and CI roles that run Terraform
#   - versioning on, so a leaked version can be identified and the credential
#     rotated
#
# The Secret names and keys deliberately match what modules/aws/external_secrets
# projects, so reactory_app is wired identically on every cloud and a workload
# layer can move between the two approaches without touching the app module.
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
  }
}

locals {
  # Mirrors secret_schema in modules/aws/external_secrets: the same Secret names
  # and the same keys, so consumers cannot tell the two apart.
  candidates = {
    mongo = {
      k8s_name = "mongo"
      data     = { username = var.mongo_username, password = var.mongo_password }
    }
    postgres = {
      k8s_name = "postgres"
      data     = { username = var.postgres_username, password = var.postgres_password }
    }
    valkey = {
      k8s_name = "valkey"
      data     = { auth_token = var.valkey_auth_token }
    }
    meili = {
      k8s_name = "meilisearch-master-key"
      data     = { "master-key" = var.meilisearch_master_key }
    }
    opensearch = {
      k8s_name = "opensearch"
      data     = { username = var.opensearch_username, password = var.opensearch_password }
    }
    grafana = {
      k8s_name = "grafana"
      data     = { admin_password = var.grafana_admin_password }
    }
    app = {
      k8s_name = "app"
      data     = { secret_key = var.app_secret_key }
    }
  }

  # for_each iterates the plain service names, never a map derived from the
  # sensitive values — Terraform rejects sensitive for_each arguments.
  enabled = toset(var.enabled_secrets)
}

resource "kubernetes_secret" "reactory" {
  for_each = local.enabled

  metadata {
    name      = local.candidates[each.value].k8s_name
    namespace = var.namespace
    labels = merge(var.labels, {
      "app.kubernetes.io/part-of"    = "reactory"
      "app.kubernetes.io/managed-by" = "terraform"
      "reactory.io/service"          = each.value
    })
  }

  data = local.candidates[each.value].data
  type = "Opaque"
}

# ---------------------------------------------------------------------------
# Optional registry pull secret
#
# Linode has no container registry and DigitalOcean's is optional, so images
# usually come from GHCR. A private repository there needs a docker-registry
# Secret referenced by the pod's imagePullSecrets.
# ---------------------------------------------------------------------------
resource "kubernetes_secret" "registry" {
  count = var.registry_auth == null ? 0 : 1

  metadata {
    name      = var.registry_secret_name
    namespace = var.namespace
    labels = merge(var.labels, {
      "app.kubernetes.io/part-of"    = "reactory"
      "app.kubernetes.io/managed-by" = "terraform"
    })
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (var.registry_auth.server) = {
          username = var.registry_auth.username
          password = var.registry_auth.password
          auth     = base64encode("${var.registry_auth.username}:${var.registry_auth.password}")
        }
      }
    })
  }
}
