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
        app = "reactory-pwa-client"
      }
    }
    template {
      metadata {
        labels = {
          app = "reactory-pwa-client"
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

resource "kubernetes_service" "reactory_pwa_client" {
  metadata {
    name      = "reactory-pwa-client"
    namespace = var.namespace
  }
  spec {
    selector = {
      app = "reactory-pwa-client"
    }
    port {
      port        = 80
      target_port = 80
      node_port = 30001
      protocol = "TCP"
    }
    type = "NodePort"
  }
}
