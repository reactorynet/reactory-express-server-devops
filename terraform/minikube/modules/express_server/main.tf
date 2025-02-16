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
        app = "reactory-express-server"
      }
    }
    template {
      metadata {
        labels = {
          app = "reactory-express-server"
        }
      }
      spec {
        container {
          name  = "reactory-express-server"
          image = "localhost/reactory/reactory-express-server:1.1.0"
          command = ["/bin/sh"]
          args = [ "-c", "bin/run-otel.sh" ]
          env {
            name = "REACTORY_HOME"
            value = "/reactory"
          }
          env {
            name = "REACTORY_DATA"
            value = "/reactory/reactory-data"
          }
          env {
            name = "REACTORY_SERVER" 
            value = "/reactory/reactory-express-server"
          }
          env {
            name = "REACTORY_CLIENT"
            value = "/reactory/reactory-pwa-client"
          }
          env {
            name = "REACTORY_PLUGINS"
            value = "/reactory/reactory-data/plugins"
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
      node_port = 30040
      protocol = "TCP"
    }
    type = "NodePort"
  }
}
