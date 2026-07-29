# ---------------------------------------------------------------------------
# module: mongodb_selfhosted
#
# A single MongoDB pod backed by an EBS volume. This is a cost-saving measure for
# non-production environments only — it is a single point of failure with no
# replica set, no automated backup and no point-in-time recovery.
#
# Staging and production use the documentdb module instead.
#
# Credentials come from a Secret projected by External Secrets Operator, so no
# password passes through Terraform state as a Kubernetes object.
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
  labels = merge(var.labels, {
    app                            = var.name
    "app.kubernetes.io/name"       = "mongodb"
    "app.kubernetes.io/component"  = "database"
    "app.kubernetes.io/managed-by" = "terraform"
  })
}

resource "kubernetes_persistent_volume_claim" "data" {
  metadata {
    name      = "${var.name}-data"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = var.storage_class
    resources {
      requests = { storage = var.storage_size }
    }
  }

  # The gp3 StorageClass binds WaitForFirstConsumer, so the volume is not
  # provisioned until a pod schedules. Waiting here would deadlock the apply.
  wait_until_bound = false
}

resource "kubernetes_deployment" "mongodb" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = 1

    selector {
      match_labels = { app = var.name }
    }

    # One pod owns one ReadWriteOnce volume. A rolling update would try to start
    # a second pod against the same volume and stall.
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        container {
          name  = "mongodb"
          image = "mongo:${var.image_tag}"

          env {
            name = "MONGO_INITDB_ROOT_USERNAME"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = var.username_key
              }
            }
          }

          env {
            name = "MONGO_INITDB_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = var.password_key
              }
            }
          }

          env {
            name  = "MONGO_INITDB_DATABASE"
            value = var.database
          }

          port {
            container_port = 27017
            name           = "mongodb"
          }

          resources {
            requests = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
          }

          liveness_probe {
            exec {
              command = ["mongosh", "--quiet", "--eval", "db.adminCommand('ping')"]
            }
            initial_delay_seconds = 30
            period_seconds        = 20
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          readiness_probe {
            exec {
              command = ["mongosh", "--quiet", "--eval", "db.adminCommand('ping')"]
            }
            initial_delay_seconds = 15
            period_seconds        = 10
            timeout_seconds       = 10
          }

          volume_mount {
            name       = "data"
            mount_path = "/data/db"
          }
        }

        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "mongodb" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    selector = { app = var.name }
    port {
      name        = "mongodb"
      port        = 27017
      target_port = 27017
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}
