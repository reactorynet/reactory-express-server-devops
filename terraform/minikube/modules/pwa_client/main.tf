variable "namespace" {
  description = "Namespace"
  type        = string
}

resource "kubernetes_deployment" "reactory_pwa_client" {
  metadata {
    name      = "reactory-pwa-client"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "pwa-nginx"
      }
    }
    template {
      metadata {
        labels = {
          app = "pwa-nginx"
        }
      }
      spec {
        container {
          name  = "reactory-pwa-client"
          image = "localhost/reactory/reactory-pwa-client:1.1.0"
          port {
            container_port = 80
          }
        }
      }
    }
  }
}
