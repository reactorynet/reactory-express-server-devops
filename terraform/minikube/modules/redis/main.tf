resource "kubernetes_persistent_volume" "redis_data" {
  metadata {
    name = "redis-data"
  }
  spec {
    capacity = {
      storage = "1Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_source {
      host_path {
        path = "/mnt/data/redis"
      }
    }
  }
}

variable "namespace" {
  description = "Namespace"
  type        = string

}

variable "reactory_redis_password" {
  type        = string
  description = "Reactory Redis Password"
}

resource "kubernetes_persistent_volume_claim" "redis_data" {
  metadata {
    name      = "redis-data"
    namespace = var.namespace
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "reactory_redis" {
  metadata {
    name      = "reactory-redis"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "redis"
      }
    }
    template {
      metadata {
        labels = {
          app = "redis"
        }
      }
      spec {
        container {
          name    = "redis"
          image   = "redis:latest"
          command = ["redis-server", "--requirepass", var.reactory_redis_password]
          volume_mount {
            mount_path = "/data"
            name       = "redis-storage"
          }
        }
        volume {
          name = "redis-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.redis_data.metadata[0].name
          }
        }
      }
    }
  }
}
