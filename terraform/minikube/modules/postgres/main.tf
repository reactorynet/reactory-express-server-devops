variable "reactory_postgres_user" {
  description = "Postgres DB username"
  type        = string
}

variable "reactory_postgres_db" {
  description = "Postgres DB name"
  type        = string
}

variable "reactory_postgres_password" {
  description = "Postgres Password"
  type        = string
}

variable "namespace" {
  description = "Namespace"
  type        = string

}

resource "kubernetes_persistent_volume" "postgres_data" {
  metadata {
    name = "postgres-data"
  }
  spec {
    capacity = {
      storage = "2Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_source {
      host_path {
        path = "/mnt/data/postgres"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "postgres_data" {
  metadata {
    name      = "postgres-data"
    namespace = var.namespace
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "2Gi"
      }
    }
  }
}

resource "kubernetes_deployment" "reactory_postgres" {
  metadata {
    name      = "reactory-postgres"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "postgres"
      }
    }
    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }
      spec {
        container {
          name  = "postgres"
          image = "postgres:latest"
          env {
            name  = "POSTGRES_USER"
            value = var.reactory_postgres_user
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = var.reactory_postgres_password
          }
          env {
            name  = "POSTGRES_DB"
            value = var.reactory_postgres_db
          }
          volume_mount {
            mount_path = "/var/lib/postgresql/data"
            name       = "postgres-storage"
          }
        }
        volume {
          name = "postgres-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres_data.metadata[0].name
          }
        }
      }
    }
  }
}
