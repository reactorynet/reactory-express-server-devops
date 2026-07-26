# ---------------------------------------------------------------------------
# module: postgres_selfhosted
#
# A single PostgreSQL pod backed by an EBS volume. Non-production only — single
# point of failure, no replica, no automated backup, no PITR.
#
# Staging and production use the rds module (Aurora Serverless v2) instead.
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
    "app.kubernetes.io/name"       = "postgres"
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

  wait_until_bound = false
}

resource "kubernetes_deployment" "postgres" {
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

    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:${var.image_tag}"

          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = var.username_key
              }
            }
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = var.password_key
              }
            }
          }

          env {
            name  = "POSTGRES_DB"
            value = var.database
          }

          # The official image refuses to initialise into a non-empty directory,
          # and an EBS volume arrives with lost+found. PGDATA in a subdirectory
          # sidesteps that, and must match the volume_mount sub_path below.
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          port {
            container_port = 5432
            name           = "postgres"
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

          # Read the user and database from the container environment rather than
          # interpolating the sensitive variables into the pod spec.
          liveness_probe {
            exec {
              command = ["sh", "-c", "pg_isready -U \"$POSTGRES_USER\" -d \"$POSTGRES_DB\""]
            }
            initial_delay_seconds = 30
            period_seconds        = 20
            timeout_seconds       = 10
            failure_threshold     = 3
          }

          readiness_probe {
            exec {
              command = ["sh", "-c", "pg_isready -U \"$POSTGRES_USER\" -d \"$POSTGRES_DB\""]
            }
            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 10
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
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

resource "kubernetes_service" "postgres" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    selector = { app = var.name }
    port {
      name        = "postgres"
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}
