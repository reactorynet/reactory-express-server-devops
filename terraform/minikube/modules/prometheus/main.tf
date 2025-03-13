variable "namespace" {
  description = "Namespace"
  type        = string  
}

variable "server_modules_root" {
  description = "The root path of the server modules"
  type        = string
}


resource "kubernetes_deployment" "reactory_prometheus" {
  metadata {
    name      = "reactory-prometheus"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "reactory-prometheus"
      }
    }
    template {
      metadata {
        labels = {
          app = "reactory-prometheus"
        }
      }
      spec {
        container {
          name  = "reactory-prometheus"
          image = "prom/prometheus:latest"
          volume_mount {
            mount_path = "/etc/prometheus"
            name       = "prometheus-config"
          }        
        }
        volume {
          name = "prometheus-config"
          host_path {
            path = "/etc/prometheus"
          }
        }
      }
    }
  }
}


resource "kubernetes_service" "reactory_prometheus" {
  metadata {
    name      = "reactory-prometheus"
    namespace = var.namespace
  }
  spec {
    selector = {
      app = "reactory-prometheus"
    }
    port {
      port        = 9090
      target_port = 9090
      node_port = 30090
    }
  }
}
