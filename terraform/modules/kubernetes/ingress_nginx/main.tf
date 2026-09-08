# ---------------------------------------------------------------------------
# module: ingress_nginx
#
# ingress-nginx plus, optionally, cert-manager with a Let's Encrypt ClusterIssuer.
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
  }
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_chart_version
  namespace        = var.namespace
  create_namespace = true

  wait    = false
  timeout = var.helm_timeout_seconds

  values = [yamlencode({
    controller = {
      replicaCount = var.replica_count

      admissionWebhooks = {
        enabled = false
        patch = {
          enabled = false
        }
      }

      service = {
        annotations           = var.service_annotations
        type                  = "LoadBalancer"
        externalTrafficPolicy = var.external_traffic_policy
      }

      metrics = {
        enabled = var.enable_metrics
      }

      resources = {
        requests = {
          cpu    = var.cpu_request
          memory = var.memory_request
        }
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }

      config = merge(
        {
          "proxy-read-timeout"    = tostring(var.proxy_timeout_seconds)
          "proxy-send-timeout"    = tostring(var.proxy_timeout_seconds)
          "proxy-body-size"       = var.proxy_body_size
          "use-forwarded-headers" = "true"
          "enable-real-ip"        = "true"
        },
        var.controller_config,
      )
    }
  })]
}

# ---------------------------------------------------------------------------
# cert-manager
# ---------------------------------------------------------------------------
resource "helm_release" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_chart_version
  namespace        = var.cert_manager_namespace
  create_namespace = true

  wait    = false
  timeout = var.helm_timeout_seconds

  set {
    name  = "crds.enabled"
    value = "true"
  }
}

# ---------------------------------------------------------------------------
# Let's Encrypt ClusterIssuer
# ---------------------------------------------------------------------------
resource "helm_release" "cluster_issuer" {
  count = var.enable_cert_manager ? 1 : 0

  name      = "letsencrypt-issuer"
  chart     = "${path.module}/chart"
  namespace = var.cert_manager_namespace

  wait    = false
  timeout = var.helm_timeout_seconds

  values = [yamlencode({
    issuer = {
      name          = var.cluster_issuer_name
      email         = var.acme_email
      server        = var.acme_server
      privateKeyRef = "${var.cluster_issuer_name}-account-key"
      ingressClass  = var.ingress_class_name
    }
  })]

  depends_on = [helm_release.cert_manager, helm_release.ingress_nginx]
}

# ---------------------------------------------------------------------------
# Read the load balancer address back off the controller Service.
# ---------------------------------------------------------------------------
data "kubernetes_service" "controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = var.namespace
  }

  depends_on = [helm_release.ingress_nginx]
}
