# ---------------------------------------------------------------------------
# module: valkey_selfhosted
#
# A single Valkey pod with AUTH enabled and an optional persistent volume.
#
# Used where no managed Redis-compatible service exists or is warranted:
#   - Linode at every tier — Akamai removed MongoDB and Redis from Linode
#     Managed Databases, leaving only MySQL and PostgreSQL
#   - DigitalOcean at the small tier, where a managed Valkey cluster costs more
#     than the rest of the environment combined
#
# Single point of failure, no replica, no automatic failover. DigitalOcean's
# medium and large tiers use the managed `valkey` engine instead.
#
# Unlike ElastiCache this does NOT enable TLS. Managed Valkey on DigitalOcean
# requires TLS; this does not offer it, which is why the tier configuration sets
# redis.tls accordingly rather than assuming.
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
    "app.kubernetes.io/name"       = "valkey"
    "app.kubernetes.io/component"  = "cache"
    "app.kubernetes.io/managed-by" = "terraform"
  })

  # requirepass goes in the config file rather than argv, so the password does
  # not appear in `ps` output inside the container. __VALKEY_PASSWORD__ is a
  # placeholder the entrypoint substitutes — deliberately not $VAR syntax, which
  # Terraform would try to interpolate.
  config = <<-CONF
    requirepass __VALKEY_PASSWORD__
    maxmemory ${var.maxmemory}
    maxmemory-policy ${var.maxmemory_policy}
    appendonly ${var.persistence_enabled ? "yes" : "no"}
  CONF
}

resource "kubernetes_config_map" "valkey" {
  metadata {
    name      = "${var.name}-config"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    "valkey.conf.template" = local.config
  }
}

resource "kubernetes_persistent_volume_claim" "data" {
  count = var.persistence_enabled ? 1 : 0

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

resource "kubernetes_deployment" "valkey" {
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

    # One pod, one ReadWriteOnce volume — a rolling update would stall trying to
    # attach the volume to a second pod.
    strategy {
      type = "Recreate"
    }

    template {
      metadata {
        labels = local.labels
      }

      spec {
        container {
          name  = "valkey"
          image = "${var.image_repository}:${var.image_tag}"

          # Substitute the password into the config at start-up so it reaches
          # Valkey without ever appearing in the pod spec or the process args.
          # The ConfigMap is read-only, hence writing the result to /tmp.
          command = ["/bin/sh", "-c"]
          args = [
            "set -e; sed \"s|__VALKEY_PASSWORD__|$VALKEY_PASSWORD|\" /config/valkey.conf.template > /tmp/valkey.conf; exec valkey-server /tmp/valkey.conf"
          ]

          env {
            name = "VALKEY_PASSWORD"
            value_from {
              secret_key_ref {
                name = var.secret_name
                key  = var.password_key
              }
            }
          }

          port {
            container_port = 6379
            name           = "valkey"
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
              command = ["/bin/sh", "-c", "valkey-cli -a \"$VALKEY_PASSWORD\" --no-auth-warning ping"]
            }
            initial_delay_seconds = 20
            period_seconds        = 20
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            exec {
              command = ["/bin/sh", "-c", "valkey-cli -a \"$VALKEY_PASSWORD\" --no-auth-warning ping"]
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 5
          }

          volume_mount {
            name       = "config"
            mount_path = "/config"
            read_only  = true
          }

          dynamic "volume_mount" {
            for_each = var.persistence_enabled ? [1] : []
            content {
              name       = "data"
              mount_path = "/data"
            }
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.valkey.metadata[0].name
          }
        }

        dynamic "volume" {
          for_each = var.persistence_enabled ? [1] : []
          content {
            name = "data"
            persistent_volume_claim {
              claim_name = kubernetes_persistent_volume_claim.data[0].metadata[0].name
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "valkey" {
  metadata {
    name      = var.name
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    selector = { app = var.name }
    port {
      name        = "valkey"
      port        = 6379
      target_port = 6379
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}
