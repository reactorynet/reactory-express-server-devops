resource "kubernetes_deployment" "reactory_nginx" {
  metadata {
    name      = "reactory-nginx"
    namespace = var.namespace
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "nginx"
      }
    }
    template {
      metadata {
        labels = {
          app = "nginx"
        }
      }
      spec {
        container {
          name  = "nginx"
          image = "nginx:1.14.2"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}

variable "namespace" {
  description = "Namespace"
  type        = string
  
}

resource "kubernetes_service" "reactory_nginx" {
  metadata {
    name      = "reactory-nginx"
    namespace = var.namespace
  }
  spec {
    selector = {
      app = "nginx"
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "NodePort"
  }
}
