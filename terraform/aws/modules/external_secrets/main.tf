# ---------------------------------------------------------------------------
# module: external_secrets
#
# The Kubernetes half of secret handling: External Secrets Operator, the
# ClusterSecretStore pointing at Secrets Manager, and one ExternalSecret per
# service projecting into a native Kubernetes Secret.
#
# The AWS half — the Secrets Manager entries and the IRSA role — lives in
# modules/secrets_manager in the cluster layer.
#
# The custom resources are delivered by a local Helm chart (./chart) rather than
# kubernetes_manifest resources. kubernetes_manifest requires a reachable API
# server *and* a registered CRD at plan time; on a first apply the ESO CRDs do
# not exist yet, so planning fails. helm_release defers all of that to apply.
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    helm = {
      # 2.x only: 3.x changed `set` and `kubernetes` from blocks to attributes.
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
  }
}

locals {
  # k8s_name is the Secret name workloads reference in secret_key_ref.
  # keys maps Kubernetes secret key => property of the Secrets Manager JSON.
  secret_schema = {
    mongo = {
      k8s_name = "mongo"
      keys     = { username = "username", password = "password" }
    }
    postgres = {
      k8s_name = "postgres"
      keys     = { username = "username", password = "password" }
    }
    valkey = {
      k8s_name = "valkey"
      keys     = { auth_token = "auth_token" }
    }
    meili = {
      # The meilisearch module reads the key as `master-key`.
      k8s_name = "meilisearch-master-key"
      keys     = { "master-key" = "master_key" }
    }
    opensearch = {
      k8s_name = "opensearch"
      keys     = { username = "username", password = "password" }
    }
    grafana = {
      k8s_name = "grafana"
      keys     = { admin_password = "admin_password" }
    }
    app = {
      k8s_name = "app"
      keys     = { secret_key = "secret_key" }
    }
  }
}

resource "kubernetes_namespace" "external_secrets" {
  metadata {
    name = var.eso_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}

resource "helm_release" "eso" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  version    = var.eso_chart_version
  namespace  = kubernetes_namespace.external_secrets.metadata[0].name

  # The reactory_secrets release below applies ESO custom resources, so the CRDs
  # must be registered and the webhook ready before it runs.
  wait          = true
  wait_for_jobs = true
  timeout       = var.helm_timeout_seconds

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = var.eso_service_account
  }

  # Binds the operator to the IRSA role created in the cluster layer.
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = var.eso_role_arn
  }

  depends_on = [kubernetes_namespace.external_secrets]
}

resource "helm_release" "reactory_secrets" {
  name      = "reactory-secrets"
  chart     = "${path.module}/chart"
  namespace = var.target_namespace

  wait    = true
  timeout = var.helm_timeout_seconds

  values = [yamlencode({
    esoApiVersion = var.eso_api_version

    clusterSecretStore = {
      name   = var.cluster_secret_store_name
      region = var.aws_region
      serviceAccount = {
        name      = var.eso_service_account
        namespace = kubernetes_namespace.external_secrets.metadata[0].name
      }
    }

    externalSecrets = [
      for name in var.enabled_secrets : {
        name            = local.secret_schema[name].k8s_name
        namespace       = lookup(var.namespace_overrides, name, var.target_namespace)
        remoteRef       = var.secret_names[name]
        refreshInterval = var.refresh_interval
        data = [
          for k8s_key, property in local.secret_schema[name].keys : {
            secretKey = k8s_key
            property  = property
          }
        ]
      }
    ]
  })]

  depends_on = [helm_release.eso]
}
