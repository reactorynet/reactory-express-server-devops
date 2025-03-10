variable "reactory_grafana_admin_password" {
  description = "The admin password for Grafana"
  type        = string
}

variable "namespace" {
  description = "Namespace"
  type        = string
  
}

variable "server_modules_root" {
  description = "The root path of the server modules"
  type        = string
}


resource "kubernetes_deployment" "reactory_grafana" {
  metadata {
    name      = "reactory-grafana"
    namespace = var.namespace
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "reactory-grafana"
      }
    }
    template {
      metadata {
        labels = {
          app = "reactory-grafana"
        }
      }
      spec {
        container {
          name  = "reactory-grafana"
          image = "grafana/grafana:latest"
          env {
            name  = "GF_SERVER_ROOT_CA_CERT"
            value = "/etc/ssl/certs/ca-certificates.crt"
          }
          env {
            name  = "GF_SERVER_HTTP_PORT"
            value = "80"
          }
          env {
            name  = "GF_SECURITY_ADMIN_PASSWORD"
            value = var.reactory_grafana_admin_password
          }
          volume_mount {
            mount_path = "/etc/grafana/provisioning"
            name       = "grafana-provisioning"
          }
          volume_mount {
            mount_path = "/etc/grafana/dashboards"
            name       = "grafana-dashboards"
          }
        }
        volume {
          name = "grafana-provisioning"
          host_path {
            path = "/etc/grafana/provisioning"
          }
        }
        volume {
          name = "grafana-dashboards"
          host_path {
            path = "/etc/grafana/models/dashboards"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "reactory_grafana" {
  metadata {
    name      = "reactory-grafana"
    namespace = var.namespace
  }
  spec {
    selector = {
      app = "reactory-grafana"
    }
    port {
      port        = 80
      target_port = 80
      node_port = 30003
      protocol = "TCP"
    }
    type = "NodePort"
  }
}
