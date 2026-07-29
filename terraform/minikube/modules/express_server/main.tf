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
          name    = "reactory-express-server"
          image   = "localhost/reactory/reactory-express-server:1.1.0"
          command = ["/bin/sh"]
          args    = ["-c", "bin/run-otel.sh"]
          env {
            name  = "REACTORY_HOME"
            value = "/reactory"
          }
          env {
            name  = "REACTORY_DATA"
            value = "/reactory/reactory-data"
          }
          env {
            name  = "REACTORY_SERVER"
            value = "/reactory/reactory-express-server"
          }
          env {
            name  = "REACTORY_CLIENT"
            value = "/reactory/reactory-pwa-client"
          }
          env {
            name  = "REACTORY_PLUGINS"
            value = "/reactory/reactory-data/plugins"
          }

          volume_mount {
            name       = "reactory-data-volume"
            mount_path = "/reactory/reactory-data"
          }
        }

        volume {
          name = "reactory-data-volume"
          host_path {
            path = "/var/reactory"
            type = "Directory"
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
      app = "reactory-express-server"
    }
    port {
      port        = 4000
      target_port = 4000
      protocol    = "TCP"
      node_port   = 30002
    }
    type = "NodePort"
  }
}
