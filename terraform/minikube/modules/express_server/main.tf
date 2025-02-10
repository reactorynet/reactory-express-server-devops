variable "namespace" {
  description = "Namespace"
  type        = string  
}

variable "server_root_path" {
  description = "The root path of the server modules"
  type        = string
}

variable "reactory_home" {
  description = "Reactory Home"
  type        = string
}

resource "kubernetes_persistent_volume" "reactory_data" {
  metadata {
    name = "reactory-data"
  }
  spec {
    capacity = {
      storage = "2Gi"
    }
    access_modes = ["ReadWriteOnce"]
    persistent_volume_source {
      host_path {
        path = "/var/reactory-data"        
      }      
    }
  }
}

resource "kubernetes_persistent_volume_claim" "reactory_data" {
  metadata {
    name      = "reactory-data"
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

resource "kubernetes_deployment" "reactory_express_server" {
  metadata {
    name      = "reactory-express-server"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "express-server"
      }
    }
    template {
      metadata {
        labels = {
          app = "express-server"
        }
      }
      spec {
        container {
          name  = "express-server"
          image = "localhost/reactory/reactory-express-server:1.1.0"          
        }
        volume {
          name = "reactory-data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.reactory_data.metadata[0].name
          }
        }        
        volume {
          name = "reactory-env-file"
          host_path {
            path = "/etc/reactory/.env"
            type = "FileOrCreate"
          }
        }        
      }
    }
  }
}

resource "kubernetes_service" "reactory_express_server" {
  metadata {
    name      = "reactory-express-server"
    namespace = var.namespace
  }
  spec {
    selector = {
      app = "express-server"
    }
    port {
      port        = 4000
      target_port = 4000
    }
    type = "NodePort"
  }
}
