variable "meilisearch_master_key" {
  description = "The master key for Meilisearch"
  type        = string
}

variable "namespace" {
  description = "Namespace"
  type        = string

}


resource "kubernetes_persistent_volume" "meilisearch_data" {
  metadata {
    name = "meilisearch-data"
  }
  spec {
    capacity = {
      storage = "5Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_source {
      host_path {
        path = "/mnt/data/meilisearch"
      }
    }
  }
}


resource "kubernetes_persistent_volume_claim" "meilisearch_data" {
  metadata {
    name      = "meilisearch-data"
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

resource "kubernetes_deployment" "reactory_meilisearch" {
  metadata {
    name      = "reactory-meilisearch"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "meilisearch"
      }
    }
    template {
      metadata {
        labels = {
          app = "meilisearch"
        }
      }
      spec {
        container {
          name  = "meilisearch"
          image = "getmeili/meilisearch:latest"
          env {
            name  = "MEILISEARCH_MASTER_KEY"
            value = var.meilisearch_master_key
          }
          volume_mount {
            mount_path = "/data.ms"
            name       = "meilisearch-storage"
          }
        }
        volume {
          name = "meilisearch-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.meilisearch_data.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "reactory_meilisearch" {
  metadata {
    name      = "reactory-meilisearch"
    namespace = var.namespace
  }
  spec {
    selector = {
      app = "meilisearch"
    }
    port {
      port        = 7700
      target_port = 7700
      node_port   = 30006
    }
  }
}