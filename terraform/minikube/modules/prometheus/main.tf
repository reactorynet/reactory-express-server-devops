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
        app = "prometheus"
      }
    }
    template {
      metadata {
        labels = {
          app = "prometheus"
        }
      }
      spec {
        container {
          name  = "prometheus"
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
            type = "DirectoryOrCreate"
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
      app = "prometheus"
    }
    port {
      port        = 9090
      target_port = 9090
    }
    type = "NodePort"
  }
}
