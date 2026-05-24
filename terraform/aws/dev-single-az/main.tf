# ---------------------------------------------------------------------------
# Blueprint: dev-single-az
# Low-cost developer environment in us-west-1.
#
# Topology:
#   - EKS cluster with SPOT t3.medium nodes (single AZ)
#   - Self-hosted MongoDB, PostgreSQL on EKS with EBS gp3 PVCs
#   - ElastiCache Valkey single node (managed, replaces self-hosted Redis)
#   - Self-hosted Meilisearch on EKS
#   - ALB Ingress Controller (no WAF, no ACM unless domain provided)
#   - Prometheus + Grafana + Jaeger via kube-prometheus-stack
#   - Single NAT gateway (cost optimisation)
#   - Remote state in S3 (see backend.tf)
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.17.0"
    }
    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
  required_version = ">= 1.8.0"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# Kubernetes + Helm providers resolve after EKS is created
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

locals {
  cluster_name = "${var.project}-${var.environment}"
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Blueprint   = "dev-single-az"
  }
}

# ---------------------------------------------------------------------------
# Reactory namespace
# ---------------------------------------------------------------------------
resource "kubernetes_namespace" "reactory" {
  metadata {
    name = "reactory"
  }
  depends_on = [module.eks]
}

# ---------------------------------------------------------------------------
# gp3 StorageClass (default for all PVCs — better price/perf than gp2)
# ---------------------------------------------------------------------------
resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }
  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true
  parameters = {
    type      = "gp3"
    encrypted = "true"
  }
  depends_on = [module.eks]
}

# ---------------------------------------------------------------------------
# Modules
# ---------------------------------------------------------------------------
module "vpc" {
  source = "../modules/vpc"

  cluster_name         = local.cluster_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = [var.availability_zones[0]]   # single AZ for dev
  public_subnet_cidrs  = [var.public_subnet_cidrs[0]]
  private_subnet_cidrs = [var.private_subnet_cidrs[0]]
  single_nat_gateway   = true
  tags                 = local.common_tags
}

module "eks" {
  source = "../modules/eks"

  cluster_name        = local.cluster_name
  kubernetes_version  = var.kubernetes_version
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_api_endpoint = true
  api_allowed_cidrs   = var.api_allowed_cidrs

  node_instance_types = ["t3.medium", "t3.large"]
  node_capacity_type  = "SPOT"
  node_desired_count  = 2
  node_min_count      = 1
  node_max_count      = 4
  node_disk_size_gb   = 30

  tags = local.common_tags
}

module "ecr" {
  source       = "../modules/ecr"
  force_delete = true   # safe for dev
  tags         = local.common_tags
}

module "valkey" {
  source = "../modules/elasticache_valkey"

  cluster_name       = local.cluster_name
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr
  private_subnet_ids = module.vpc.private_subnet_ids
  mode               = "single"
  node_type          = "cache.t4g.small"
  auth_token         = var.valkey_auth_token
  multi_az           = false
  snapshot_retention_days = 0

  tags = local.common_tags
}

module "secrets" {
  source = "../modules/secrets"

  cluster_name      = local.cluster_name
  aws_region        = var.aws_region
  secret_prefix     = "${var.project}/${var.environment}"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  recovery_window_days = 0   # immediate deletion for dev

  mongo_username         = var.mongo_username
  mongo_password         = var.mongo_password
  postgres_username      = var.postgres_username
  postgres_password      = var.postgres_password
  valkey_auth_token      = var.valkey_auth_token
  meilisearch_master_key = var.meilisearch_master_key
  grafana_admin_password = var.grafana_admin_password
  app_secret_key         = var.app_secret_key

  tags = local.common_tags
}

module "meilisearch" {
  source = "../modules/meilisearch"

  namespace              = kubernetes_namespace.reactory.metadata[0].name
  master_key_secret_name = "meilisearch-master-key"
  storage_class          = kubernetes_storage_class.gp3.metadata[0].name
  storage_size           = "5Gi"
  meili_env              = "development"

  depends_on = [module.secrets, kubernetes_storage_class.gp3]
}

module "alb_ingress" {
  source = "../modules/alb_ingress"

  cluster_name      = local.cluster_name
  aws_region        = var.aws_region
  vpc_id            = module.vpc.vpc_id
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  domain_name       = var.domain_name

  tags = local.common_tags
}

module "observability" {
  source = "../modules/observability"

  grafana_admin_password   = var.grafana_admin_password
  storage_class            = kubernetes_storage_class.gp3.metadata[0].name
  prometheus_retention     = "7d"
  prometheus_storage_size  = "10Gi"
  install_jaeger           = true

  depends_on = [kubernetes_storage_class.gp3]
}

# ---------------------------------------------------------------------------
# MongoDB — self-hosted on EKS with EBS gp3 (dev pattern)
# ---------------------------------------------------------------------------
resource "kubernetes_persistent_volume_claim" "mongodb" {
  metadata {
    name      = "mongodb-data"
    namespace = kubernetes_namespace.reactory.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.gp3.metadata[0].name
    resources {
      requests = { storage = "5Gi" }
    }
  }
}

resource "kubernetes_secret" "mongodb_creds" {
  metadata {
    name      = "mongodb-credentials"
    namespace = kubernetes_namespace.reactory.metadata[0].name
  }
  data = {
    username = var.mongo_username
    password = var.mongo_password
    database = var.mongo_database
  }
  type = "Opaque"
}

resource "kubernetes_deployment" "mongodb" {
  metadata {
    name      = "mongodb"
    namespace = kubernetes_namespace.reactory.metadata[0].name
    labels    = { app = "mongodb" }
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "mongodb" }
    }
    template {
      metadata {
        labels = { app = "mongodb" }
      }
      spec {
        container {
          name  = "mongodb"
          image = "mongo:7.0.14"

          env {
            name = "MONGO_INITDB_ROOT_USERNAME"
            value_from {
              secret_key_ref { name = kubernetes_secret.mongodb_creds.metadata[0].name; key = "username" }
            }
          }
          env {
            name = "MONGO_INITDB_ROOT_PASSWORD"
            value_from {
              secret_key_ref { name = kubernetes_secret.mongodb_creds.metadata[0].name; key = "password" }
            }
          }
          env {
            name = "MONGO_INITDB_DATABASE"
            value_from {
              secret_key_ref { name = kubernetes_secret.mongodb_creds.metadata[0].name; key = "database" }
            }
          }

          port { container_port = 27017 }

          resources {
            requests = { cpu = "250m", memory = "256Mi" }
            limits   = { cpu = "1", memory = "1Gi" }
          }

          liveness_probe {
            exec { command = ["mongosh", "--eval", "db.adminCommand('ping')"] }
            initial_delay_seconds = 30
            period_seconds        = 20
          }

          readiness_probe {
            exec { command = ["mongosh", "--eval", "db.adminCommand('ping')"] }
            initial_delay_seconds = 15
            period_seconds        = 10
          }

          volume_mount {
            name       = "data"
            mount_path = "/data/db"
          }
        }
        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.mongodb.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "mongodb" {
  metadata {
    name      = "mongodb"
    namespace = kubernetes_namespace.reactory.metadata[0].name
  }
  spec {
    selector = { app = "mongodb" }
    port {
      port        = 27017
      target_port = 27017
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}

# ---------------------------------------------------------------------------
# PostgreSQL — self-hosted on EKS (dev pattern)
# ---------------------------------------------------------------------------
resource "kubernetes_persistent_volume_claim" "postgres" {
  metadata {
    name      = "postgres-data"
    namespace = kubernetes_namespace.reactory.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.gp3.metadata[0].name
    resources {
      requests = { storage = "5Gi" }
    }
  }
}

resource "kubernetes_secret" "postgres_creds" {
  metadata {
    name      = "postgres-credentials"
    namespace = kubernetes_namespace.reactory.metadata[0].name
  }
  data = {
    username = var.postgres_username
    password = var.postgres_password
    database = var.postgres_database
  }
  type = "Opaque"
}

resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.reactory.metadata[0].name
    labels    = { app = "postgres" }
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "postgres" }
    }
    template {
      metadata {
        labels = { app = "postgres" }
      }
      spec {
        container {
          name  = "postgres"
          image = "postgres:16.4"

          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref { name = kubernetes_secret.postgres_creds.metadata[0].name; key = "username" }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref { name = kubernetes_secret.postgres_creds.metadata[0].name; key = "password" }
            }
          }
          env {
            name = "POSTGRES_DB"
            value_from {
              secret_key_ref { name = kubernetes_secret.postgres_creds.metadata[0].name; key = "database" }
            }
          }

          port { container_port = 5432 }

          resources {
            requests = { cpu = "250m", memory = "256Mi" }
            limits   = { cpu = "1", memory = "1Gi" }
          }

          liveness_probe {
            exec { command = ["pg_isready", "-U", var.postgres_username] }
            initial_delay_seconds = 30
            period_seconds        = 20
          }

          readiness_probe {
            exec { command = ["pg_isready", "-U", var.postgres_username] }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
            sub_path   = "pgdata"
          }
        }
        volume {
          name = "data"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres.metadata[0].name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres"
    namespace = kubernetes_namespace.reactory.metadata[0].name
  }
  spec {
    selector = { app = "postgres" }
    port {
      port        = 5432
      target_port = 5432
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}

# ---------------------------------------------------------------------------
# Express server deployment
# ---------------------------------------------------------------------------
resource "kubernetes_deployment" "express_server" {
  metadata {
    name      = "reactory-express-server"
    namespace = kubernetes_namespace.reactory.metadata[0].name
    labels    = { app = "reactory-express-server" }
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "reactory-express-server" }
    }
    template {
      metadata {
        labels = { app = "reactory-express-server" }
      }
      spec {
        container {
          name  = "reactory-express-server"
          image = "${module.ecr.express_server_url}:${var.image_tag}"
          command = ["/bin/sh"]
          args    = ["-c", "bin/run-otel.sh"]

          env { name = "REACTORY_HOME";    value = "/reactory" }
          env { name = "REACTORY_DATA";    value = "/reactory/reactory-data" }
          env { name = "REACTORY_SERVER";  value = "/reactory/reactory-express-server" }
          env { name = "REACTORY_CLIENT";  value = "/reactory/reactory-pwa-client" }
          env { name = "REACTORY_PLUGINS"; value = "/reactory/reactory-data/plugins" }

          env {
            name = "MONGO_URI"
            value = "mongodb://${var.mongo_username}:$(MONGO_PASSWORD)@mongodb.reactory.svc.cluster.local:27017/${var.mongo_database}"
          }
          env {
            name = "MONGO_PASSWORD"
            value_from {
              secret_key_ref { name = kubernetes_secret.mongodb_creds.metadata[0].name; key = "password" }
            }
          }
          env {
            name = "REDIS_URL"
            value = "rediss://:$(VALKEY_AUTH_TOKEN)@${module.valkey.primary_endpoint}:6379"
          }
          env {
            name = "VALKEY_AUTH_TOKEN"
            value_from {
              secret_key_ref { name = "valkey-credentials"; key = "auth_token" }
            }
          }

          port { container_port = 4000 }

          resources {
            requests = { cpu = "250m", memory = "512Mi" }
            limits   = { cpu = "2", memory = "2Gi" }
          }

          liveness_probe {
            http_get { path = "/health"; port = 4000 }
            initial_delay_seconds = 45
            period_seconds        = 20
            failure_threshold     = 3
          }

          readiness_probe {
            http_get { path = "/health"; port = 4000 }
            initial_delay_seconds = 20
            period_seconds        = 10
          }
        }
      }
    }
  }
  depends_on = [module.secrets]
}

resource "kubernetes_service" "express_server" {
  metadata {
    name      = "reactory-express-server"
    namespace = kubernetes_namespace.reactory.metadata[0].name
  }
  spec {
    selector = { app = "reactory-express-server" }
    port {
      port        = 4000
      target_port = 4000
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}

# ---------------------------------------------------------------------------
# PWA client deployment
# ---------------------------------------------------------------------------
resource "kubernetes_deployment" "pwa_client" {
  metadata {
    name      = "reactory-pwa-client"
    namespace = kubernetes_namespace.reactory.metadata[0].name
    labels    = { app = "reactory-pwa-client" }
  }
  spec {
    replicas = 1
    selector {
      match_labels = { app = "reactory-pwa-client" }
    }
    template {
      metadata {
        labels = { app = "reactory-pwa-client" }
      }
      spec {
        container {
          name  = "reactory-pwa-client"
          image = "${module.ecr.pwa_client_url}:${var.image_tag}"

          port { container_port = 80 }

          resources {
            requests = { cpu = "100m", memory = "128Mi" }
            limits   = { cpu = "500m", memory = "512Mi" }
          }

          liveness_probe {
            http_get { path = "/"; port = 80 }
            initial_delay_seconds = 20
            period_seconds        = 20
          }

          readiness_probe {
            http_get { path = "/"; port = 80 }
            initial_delay_seconds = 10
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "pwa_client" {
  metadata {
    name      = "reactory-pwa-client"
    namespace = kubernetes_namespace.reactory.metadata[0].name
  }
  spec {
    selector = { app = "reactory-pwa-client" }
    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}

# ---------------------------------------------------------------------------
# Ingress — ALB routing pwa-client and express-server
# ---------------------------------------------------------------------------
resource "kubernetes_ingress_v1" "reactory" {
  metadata {
    name      = "reactory-ingress"
    namespace = kubernetes_namespace.reactory.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                        = "alb"
      "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"              = "ip"
      "alb.ingress.kubernetes.io/listen-ports"             = jsonencode([{ HTTP = 80 }])
    }
  }
  spec {
    rule {
      http {
        path {
          path      = "/api"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.express_server.metadata[0].name
              port { number = 4000 }
            }
          }
        }
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.pwa_client.metadata[0].name
              port { number = 80 }
            }
          }
        }
      }
    }
  }
  depends_on = [module.alb_ingress]
}
