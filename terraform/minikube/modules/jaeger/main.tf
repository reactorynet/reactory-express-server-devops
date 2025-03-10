
variable "namespace" {
  description = "Namespace"
  type        = string
}

resource "kubernetes_deployment" "reactory_jaeger" {
  metadata {
    name      = "reactory-jaeger"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "jaeger"
      }
    }
    template {
      metadata {
        labels = {
          app = "jaeger"
        }
      }
      spec {
        container {
          name  = "jaeger"
          image = "jaegertracing/all-in-one:latest"
          port {
            container_port = 4318
          }
          port {
            container_port = 16686
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "reactory_jaeger" {  
  metadata {
    name      = "reactory-jaeger"
    namespace = var.namespace
  }
  spec {
    selector = {
      app = "jaeger"
    }
    port {
      port        = 4318
      target_port = 4318
      name = "query"
      node_port = 30004
    }
    port {
      port        = 80
      target_port = 80
      name = "web"
      node_port = 30005
    }
    type = "NodePort"
  }
}
