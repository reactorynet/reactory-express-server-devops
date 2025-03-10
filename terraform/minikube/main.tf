terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.17.0"
    }
    kubectl = {
      source = "gavinbunney/kubectl"
      version = "1.19.0"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
  config_context = "reactory"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
    config_context = "reactory"
  }
}

resource "kubernetes_namespace" "reactory" {
  metadata {
    name = "reactory"
  }
}

# Variables start
output "reactory_namespace" {
  value = kubernetes_namespace.reactory.metadata[0].name
}

variable "reactory_mongo_password" {
  description = "Mongo password"
  type        = string
  default = "reactorycore"
}

variable "reactory_mongo_user" {
  description = "MongoDB user"
  type        = string
  default = "reactory"
}

variable "reactory_mongo_db" {
  description = "MongoDB init database"
  type        = string
  default = "reactory-minikube-reactory"
}

variable "reactory_mongo_port" {
  description = "MongoDB port"
  type = number
  default = 27017
}

variable "reactory_postgres_user" {
  description = "Postgres DB username"
  type = string
  default = "reactory"
}

variable "reactory_postgres_db" {
  description = "Postgres DB name"
  type = string
  default = "reactory"
}

variable "reactory_postgres_password" {
  description = "Postgres Password"
  type = string
  default = "reactory"
}

variable "reactory_postgres_host" {
  description = "Postgres Host"
  type = string
  default = "reactory-postgres"
}

variable "reactory_postgres_port" {
  description = "Postgres Port"
  type = number
}

variable "reactory_redis_password" {
  type = string
  description = "Reactory Redis Password"
  default = "reactory"
}

variable "reactory_meilisearch_master_key" {
  description = "The master key for Meilisearch"
  type        = string
}

variable "reactory_grafana_admin_password" {
  description = "The admin password for Grafana"
  type        = string
}

variable "reactory_home" {
  description = "Reactory Home"
  type        = string
  default = "~/reactory"
}

variable "reactory_server_root" {
  description = "The root path of the server"
  type        = string
}

variable "reactory_server_modules_root" {
  description = "The root path of the server modules"
  type        = string
}


# Modules start

# 1. install istio
# module "istio" {
#   source = "./modules/istio"
# }

# 2. install mongodb
module "mongodb" {
  source = "./modules/mongodb"
  mongo_user = var.reactory_mongo_user
  mongo_db   = var.reactory_mongo_db 
  mongo_password = var.reactory_mongo_password
  namespace = kubernetes_namespace.reactory.metadata[0].name
}

# 3. install postgres
module "postgres" {
  source = "./modules/postgres"
  reactory_postgres_user     = var.reactory_postgres_user
  reactory_postgres_db       = var.reactory_postgres_db
  reactory_postgres_password = var.reactory_postgres_password
  namespace = kubernetes_namespace.reactory.metadata[0].name
}

# 4. install redis
module "redis" {
  source = "./modules/redis"
  reactory_redis_password = var.reactory_redis_password
  namespace = kubernetes_namespace.reactory.metadata[0].name
}

# 5. install meilisearch
module "meilisearch" {
  source = "./modules/meilisearch"
  meilisearch_master_key = var.reactory_meilisearch_master_key
  namespace = kubernetes_namespace.reactory.metadata[0].name
}

# 6. install jaeger
module "jaeger" {
  source = "./modules/jaeger"
  namespace = kubernetes_namespace.reactory.metadata[0].name
}

# 7. install grafana
module "grafana" {
  source = "./modules/grafana"
  reactory_grafana_admin_password = var.reactory_grafana_admin_password
  namespace = kubernetes_namespace.reactory.metadata[0].name
  server_modules_root = var.reactory_server_modules_root
}

# 8. install prometheus
module "prometheus" {
  source = "./modules/prometheus"
  namespace = kubernetes_namespace.reactory.metadata[0].name
  server_modules_root = var.reactory_server_modules_root
}

# 9. install express server
module "express_server" {
  source = "./modules/express_server"
  namespace = kubernetes_namespace.reactory.metadata[0].name
  server_root_path = var.reactory_server_root
  reactory_home = var.reactory_home
}

# 10. install pwa client
module "pwa_client" {
  source = "./modules/pwa_client"
  namespace = kubernetes_namespace.reactory.metadata[0].name
}