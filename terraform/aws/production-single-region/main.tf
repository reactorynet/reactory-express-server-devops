# ---------------------------------------------------------------------------
# Blueprint: production-single-region
# Production-grade, HA within 2 AZs (us-west-1), with managed AWS data services.
#
# Topology:
#   - EKS cluster — ON_DEMAND nodes, 2 AZs, Cluster Autoscaler
#   - DocumentDB (MongoDB-compatible) — 2 instances for HA
#   - Aurora PostgreSQL Serverless v2 — writer + reader instance
#   - ElastiCache Valkey — cluster mode disabled, Multi-AZ with auto-failover
#   - Amazon OpenSearch Service — 2-node, AZ-aware
#   - ALB Ingress + ACM TLS + WAF (optional)
#   - External Secrets Operator + Secrets Manager + IRSA
#   - Prometheus Operator + Grafana + Jaeger
#   - gp3 StorageClass with encryption
#   - HPA on express-server and pwa-client
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
    Blueprint   = "production-single-region"
  }
}

# ---------------------------------------------------------------------------
# Reactory namespace
# ---------------------------------------------------------------------------
resource "kubernetes_namespace" "reactory" {
  metadata {
    name = "reactory"
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
  depends_on = [module.eks]
}

# ---------------------------------------------------------------------------
# gp3 StorageClass
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
    iops      = "3000"
    throughput = "125"
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
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = false   # one NAT per AZ for HA
  tags                 = local.common_tags
}

module "eks" {
  source = "../modules/eks"

  cluster_name        = local.cluster_name
  kubernetes_version  = var.kubernetes_version
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids
  public_api_endpoint = var.public_api_endpoint
  api_allowed_cidrs   = var.api_allowed_cidrs

  node_instance_types = var.node_instance_types
  node_capacity_type  = "ON_DEMAND"
  node_desired_count  = 2
  node_min_count      = 2
  node_max_count      = 8
  node_disk_size_gb   = 50

  tags = local.common_tags
}

module "ecr" {
  source          = "../modules/ecr"
  force_delete    = false
  max_image_count = 30
  tags            = local.common_tags
}

module "documentdb" {
  source = "../modules/documentdb"

  cluster_name       = local.cluster_name
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr
  private_subnet_ids = module.vpc.private_subnet_ids
  master_username    = var.mongo_username
  master_password    = var.mongo_password
  instance_class     = var.docdb_instance_class
  instance_count     = 2   # primary + reader for HA
  backup_retention_days = 14
  deletion_protection   = true
  skip_final_snapshot   = false

  tags = local.common_tags
}

module "rds" {
  source = "../modules/rds"

  cluster_name            = local.cluster_name
  vpc_id                  = module.vpc.vpc_id
  vpc_cidr                = module.vpc.vpc_cidr
  private_subnet_ids      = module.vpc.private_subnet_ids
  database_name           = var.postgres_database
  master_username         = var.postgres_username
  master_password         = var.postgres_password
  serverless_min_capacity = 0.5
  serverless_max_capacity = var.rds_max_capacity
  instance_count          = 2   # writer + reader
  deletion_protection     = true
  skip_final_snapshot     = false

  tags = local.common_tags
}

module "valkey" {
  source = "../modules/elasticache_valkey"

  cluster_name       = local.cluster_name
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr
  private_subnet_ids = module.vpc.private_subnet_ids
  mode               = "single"
  node_type          = var.valkey_node_type
  auth_token         = var.valkey_auth_token
  multi_az           = true
  snapshot_retention_days = 7

  tags = local.common_tags
}

module "opensearch" {
  source = "../modules/opensearch"

  cluster_name       = local.cluster_name
  mode               = "managed"
  vpc_id             = module.vpc.vpc_id
  vpc_cidr           = module.vpc.vpc_cidr
  private_subnet_ids = module.vpc.private_subnet_ids
  instance_type      = var.opensearch_instance_type
  instance_count     = 2   # AZ-aware, one node per AZ
  volume_size_gb     = var.opensearch_volume_size_gb
  master_username    = var.opensearch_username
  master_password    = var.opensearch_password

  tags = local.common_tags
}

module "secrets" {
  source = "../modules/secrets"

  cluster_name      = local.cluster_name
  aws_region        = var.aws_region
  secret_prefix     = "${var.project}/${var.environment}"
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url
  recovery_window_days = 30

  mongo_username         = var.mongo_username
  mongo_password         = var.mongo_password
  postgres_username      = var.postgres_username
  postgres_password      = var.postgres_password
  valkey_auth_token      = var.valkey_auth_token
  opensearch_username    = var.opensearch_username
  opensearch_password    = var.opensearch_password
  grafana_admin_password = var.grafana_admin_password
  app_secret_key         = var.app_secret_key

  tags = local.common_tags
}

module "alb_ingress" {
  source = "../modules/alb_ingress"

  cluster_name              = local.cluster_name
  aws_region                = var.aws_region
  vpc_id                    = module.vpc.vpc_id
  oidc_provider_arn         = module.eks.oidc_provider_arn
  oidc_provider_url         = module.eks.oidc_provider_url
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names

  tags = local.common_tags
}

module "observability" {
  source = "../modules/observability"

  grafana_admin_password  = var.grafana_admin_password
  storage_class           = kubernetes_storage_class.gp3.metadata[0].name
  prometheus_retention    = "30d"
  prometheus_storage_size = "50Gi"
  install_jaeger          = true

  depends_on = [kubernetes_storage_class.gp3]
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
    replicas = var.express_server_replicas
    selector {
      match_labels = { app = "reactory-express-server" }
    }
    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "25%"
        max_unavailable = "0"
      }
    }
    template {
      metadata {
        labels = { app = "reactory-express-server" }
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "4000"
          "prometheus.io/path"   = "/metrics"
        }
      }
      spec {
        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "topology.kubernetes.io/zone"
          when_unsatisfiable = "DoNotSchedule"
          label_selector {
            match_labels = { app = "reactory-express-server" }
          }
        }

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
            name  = "MONGO_URI"
            value = "mongodb://${var.mongo_username}:$(MONGO_PASSWORD)@${module.documentdb.cluster_endpoint}:27017/${var.mongo_database}?tls=true&tlsCAFile=rds-combined-ca-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"
          }
          env {
            name = "MONGO_PASSWORD"
            value_from {
              secret_key_ref { name = "mongo"; key = "password" }
            }
          }
          env {
            name  = "POSTGRES_HOST"
            value = module.rds.cluster_endpoint
          }
          env {
            name  = "POSTGRES_PORT"
            value = tostring(module.rds.cluster_port)
          }
          env {
            name  = "POSTGRES_DB"
            value = var.postgres_database
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref { name = "postgres"; key = "password" }
            }
          }
          env {
            name  = "REDIS_URL"
            value = "rediss://:$(VALKEY_AUTH_TOKEN)@${module.valkey.primary_endpoint}:6379"
          }
          env {
            name = "VALKEY_AUTH_TOKEN"
            value_from {
              secret_key_ref { name = "valkey"; key = "auth_token" }
            }
          }
          env {
            name  = "OPENSEARCH_URL"
            value = module.opensearch.endpoint
          }
          env {
            name = "OPENSEARCH_PASSWORD"
            value_from {
              secret_key_ref { name = "opensearch"; key = "password" }
            }
          }

          port { container_port = 4000 }

          resources {
            requests = { cpu = "500m", memory = "1Gi" }
            limits   = { cpu = "2",    memory = "4Gi" }
          }

          liveness_probe {
            http_get { path = "/health"; port = 4000 }
            initial_delay_seconds = 60
            period_seconds        = 20
            failure_threshold     = 3
          }

          readiness_probe {
            http_get { path = "/health"; port = 4000 }
            initial_delay_seconds = 30
            period_seconds        = 10
            success_threshold     = 1
            failure_threshold     = 3
          }
        }
      }
    }
  }
  depends_on = [module.secrets, module.documentdb, module.rds, module.valkey]
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

resource "kubernetes_horizontal_pod_autoscaler_v2" "express_server" {
  metadata {
    name      = "reactory-express-server-hpa"
    namespace = kubernetes_namespace.reactory.metadata[0].name
  }
  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.express_server.metadata[0].name
    }
    min_replicas = var.express_server_replicas
    max_replicas = var.express_server_max_replicas
    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
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
    replicas = var.pwa_client_replicas
    selector {
      match_labels = { app = "reactory-pwa-client" }
    }
    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = "25%"
        max_unavailable = "0"
      }
    }
    template {
      metadata {
        labels = { app = "reactory-pwa-client" }
      }
      spec {
        topology_spread_constraint {
          max_skew           = 1
          topology_key       = "topology.kubernetes.io/zone"
          when_unsatisfiable = "DoNotSchedule"
          label_selector {
            match_labels = { app = "reactory-pwa-client" }
          }
        }
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
            initial_delay_seconds = 15
            period_seconds        = 20
          }
          readiness_probe {
            http_get { path = "/"; port = 80 }
            initial_delay_seconds = 5
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

resource "kubernetes_horizontal_pod_autoscaler_v2" "pwa_client" {
  metadata {
    name      = "reactory-pwa-client-hpa"
    namespace = kubernetes_namespace.reactory.metadata[0].name
  }
  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.pwa_client.metadata[0].name
    }
    min_replicas = var.pwa_client_replicas
    max_replicas = var.pwa_client_max_replicas
    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Ingress — ALB with HTTPS and ACM certificate
# ---------------------------------------------------------------------------
resource "kubernetes_ingress_v1" "reactory" {
  metadata {
    name      = "reactory-ingress"
    namespace = kubernetes_namespace.reactory.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                        = "alb"
      "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"              = "ip"
      "alb.ingress.kubernetes.io/listen-ports"             = jsonencode([{ HTTP = 80 }, { HTTPS = 443 }])
      "alb.ingress.kubernetes.io/ssl-redirect"             = "443"
      "alb.ingress.kubernetes.io/certificate-arn"          = module.alb_ingress.acm_certificate_arn
      "alb.ingress.kubernetes.io/healthcheck-path"         = "/health"
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "idle_timeout.timeout_seconds=60,routing.http2.enabled=true"
    }
  }
  spec {
    rule {
      host = var.domain_name
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
