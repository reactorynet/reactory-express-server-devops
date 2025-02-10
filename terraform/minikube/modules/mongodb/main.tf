variable "mongo_password" {
  description = "Mongo password"
  type        = string
}

variable "mongo_user" {
  description = "MongoDB user"
  type        = string
}

variable "mongo_db" {
  description = "MongoDB init database"
  type        = string
}

variable "namespace" {
  description = "Namespace"
  type        = string
  
}

resource "kubernetes_persistent_volume" "mongodb_data" {
  metadata {
    name = "mongodb-data"
  }
  spec {
    capacity = {
      storage = "2Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_source {
      host_path {
        path = "/data/mongodb"
      }      
    }
  }
}

resource "kubernetes_persistent_volume_claim" "mongodb_data" {
  metadata {
    name      = "mongodb-data"
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

resource "kubernetes_deployment" "reactory_mongodb" {
  metadata {
    name      = "reactory-mongodb"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "mongodb"
      }
    }
    template {
      metadata {
        labels = {
          app = "mongodb"
        }
      }
      spec {
        container {
          name  = "mongodb"
          image = "mongo:latest"
          env {
            name  = "MONGO_INITDB_ROOT_USERNAME"
            value = var.mongo_user
          }
          env {
            name  = "MONGO_INITDB_ROOT_PASSWORD"
            value = var.mongo_password
          }
          env {
            name  = "MONGO_INITDB_DATABASE"
            value = var.mongo_db
          }
          volume_mount {
            mount_path = "/data/db"
            name       = "mongodb-storage"
          }
        }
        volume {
          name = "mongodb-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mongodb_data.metadata[0].name
          }
        }
      }
    }
  }
}
