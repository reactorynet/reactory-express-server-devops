# ---------------------------------------------------------------------------
# module: observability
# Installs the kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
# and Jaeger tracing via Helm. Matches the minikube observability setup
# but uses Kubernetes Secrets for credentials and proper PVCs.
# ---------------------------------------------------------------------------

terraform {
  required_providers {
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

resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.namespace
  }
}

# Grafana admin password from an existing Kubernetes Secret
resource "kubernetes_secret" "grafana_admin" {
  metadata {
    name      = "grafana-admin-credentials"
    namespace = kubernetes_namespace.monitoring.metadata[0].name
  }
  data = {
    admin-user     = "admin"
    admin-password = var.grafana_admin_password
  }
  type = "Opaque"
}

# ---------------------------------------------------------------------------
# kube-prometheus-stack (Prometheus Operator + Grafana + Alertmanager)
# ---------------------------------------------------------------------------
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.prometheus_stack_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  values = [
    yamlencode({
      grafana = {
        adminPassword = var.grafana_admin_password
        persistence = {
          enabled          = true
          storageClassName = var.storage_class
          size             = "5Gi"
        }
        service = {
          type = "ClusterIP"
        }
        sidecar = {
          dashboards = { enabled = true, label = "grafana_dashboard" }
          datasources = { enabled = true }
        }
      }
      prometheus = {
        prometheusSpec = {
          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = { storage = var.prometheus_storage_size }
                }
              }
            }
          }
          retention = var.prometheus_retention
          resources = {
            requests = { cpu = "250m", memory = "512Mi" }
            limits   = { cpu = "1", memory = "2Gi" }
          }
        }
      }
      alertmanager = {
        alertmanagerSpec = {
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = { storage = "2Gi" }
                }
              }
            }
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}

# ---------------------------------------------------------------------------
# Jaeger (all-in-one for dev/staging; production should use Jaeger Operator)
# ---------------------------------------------------------------------------
resource "helm_release" "jaeger" {
  count      = var.install_jaeger ? 1 : 0
  name       = "jaeger"
  repository = "https://jaegertracing.github.io/helm-charts"
  chart      = "jaeger"
  version    = var.jaeger_chart_version
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  values = [
    yamlencode({
      allInOne = {
        enabled = true
        resources = {
          requests = { cpu = "100m", memory = "128Mi" }
          limits   = { cpu = "500m", memory = "512Mi" }
        }
      }
      storage = {
        type = "memory"
      }
      query = {
        service = { type = "ClusterIP" }
      }
      collector = {
        service = { type = "ClusterIP" }
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring]
}
