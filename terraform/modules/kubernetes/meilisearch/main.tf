# ---------------------------------------------------------------------------
# module: meilisearch
# Self-hosted Meilisearch on EKS — used for dev and staging.
# Production blueprints use the opensearch module instead.
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
  }
}

resource "kubernetes_persistent_volume_claim" "meilisearch" {
  metadata {
    name      = "meilisearch-data"
    namespace = var.namespace
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class
    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }
}

resource "kubernetes_deployment" "meilisearch" {
  metadata {
    name      = "meilisearch"
    namespace = var.namespace
    labels    = { app = "meilisearch" }
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "meilisearch" }
    }
    template {
      metadata {
        labels = { app = "meilisearch" }
      }
      spec {
        container {
          name  = "meilisearch"
          image = "getmeili/meilisearch:${var.image_tag}"

          env {
            name = "MEILI_MASTER_KEY"
            value_from {
              secret_key_ref {
                name = var.master_key_secret_name
                key  = "master-key"
              }
            }
          }
          env {
            name  = "MEILI_ENV"
            value = var.meili_env
          }

          port {
            container_port = 7700
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 7700
            }
            initial_delay_seconds = 30
            period_seconds        = 15
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 7700
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          volume_mount {
            mount_path = "/meili_data"
            name       = "data"
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.meilisearch.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "meilisearch" {
  metadata {
    name      = "meilisearch"
    namespace = var.namespace
  }
  spec {
    selector = { app = "meilisearch" }
    port {
      port        = 7700
      target_port = 7700
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}
