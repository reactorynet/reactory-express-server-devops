# ---------------------------------------------------------------------------
# dev / workload layer
#
# Everything inside the cluster: the namespace, secret projection, the
# self-hosted data services dev uses instead of managed ones, the ingress
# controller, observability, and the Reactory application itself.
#
# Requires environments/dev/cluster to have been applied first.
#
# WHY THIS LAYER EXISTS SEPARATELY
#
# The kubernetes and helm providers are configured below from
# data.terraform_remote_state, which Terraform reads during plan. Their
# configuration is therefore *known* before any resource is created.
#
# When the cluster and these workloads share one state, the provider config
# instead derives from module.eks outputs that do not exist until apply. Creation
# usually works, but destroy and cluster replacement are unreliable, because
# Terraform must configure the provider to plan the destruction of objects on a
# cluster it is simultaneously destroying. Splitting the layers removes that
# ordering problem entirely.
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      # 2.x only: 3.x changed `set` and `kubernetes` from blocks to attributes.
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
  required_version = ">= 1.8.0"
}

data "terraform_remote_state" "cluster" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    key    = "dev/cluster/terraform.tfstate"
    region = var.state_bucket_region
  }
}

locals {
  cluster = data.terraform_remote_state.cluster.outputs

  namespace = "reactory"

  common_tags = {
    Project     = local.cluster.project
    Environment = local.cluster.environment
    ManagedBy   = "terraform"
    Layer       = "workload"
  }

  # In-cluster service addresses for the self-hosted data services below.
  mongodb_host     = "mongodb.${local.namespace}.svc.cluster.local"
  postgres_host    = "postgres.${local.namespace}.svc.cluster.local"
  meilisearch_host = "http://meilisearch.${local.namespace}.svc.cluster.local:7700"

  # ALB annotations. The AWS Load Balancer Controller reads these off the
  # Ingress; without a certificate it serves plain HTTP on the generated ALB
  # hostname.
  alb_annotations = merge(
    {
      "alb.ingress.kubernetes.io/scheme"           = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/health"
      "alb.ingress.kubernetes.io/group.name"       = local.cluster.cluster_name
    },
    module.alb_ingress.acm_certificate_arn != null ? {
      "alb.ingress.kubernetes.io/listen-ports"    = jsonencode([{ HTTP = 80 }, { HTTPS = 443 }])
      "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
      "alb.ingress.kubernetes.io/certificate-arn" = module.alb_ingress.acm_certificate_arn
      } : {
      "alb.ingress.kubernetes.io/listen-ports" = jsonencode([{ HTTP = 80 }])
    },
  )

  # Without a domain the ALB hostname is unknown until after apply, so
  # api_uri_root can be supplied explicitly on a second pass.
  api_uri_root = (
    var.api_uri_root != "" ? var.api_uri_root
    : var.domain_name != "" ? "https://${var.domain_name}"
    : "http://reactory-express-server.${local.namespace}.svc.cluster.local:4000"
  )
}

provider "aws" {
  region = local.cluster.aws_region

  default_tags {
    tags = local.common_tags
  }
}

provider "kubernetes" {
  host                   = local.cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster.cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.cluster.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = local.cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(local.cluster.cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", local.cluster.cluster_name]
    }
  }
}

# ---------------------------------------------------------------------------
# Namespace and storage
# ---------------------------------------------------------------------------
resource "kubernetes_namespace" "reactory" {
  metadata {
    name = local.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "reactory.io/environment"      = local.cluster.environment
    }
  }
}

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
}

# ---------------------------------------------------------------------------
# Secret projection
# ---------------------------------------------------------------------------
module "external_secrets" {
  source = "../../../modules/external_secrets"

  aws_region          = local.cluster.aws_region
  enabled_secrets     = local.cluster.enabled_secrets
  secret_names        = local.cluster.secret_names
  eso_role_arn        = local.cluster.eso_role_arn
  eso_namespace       = local.cluster.eso_namespace
  eso_service_account = local.cluster.eso_service_account
  target_namespace    = kubernetes_namespace.reactory.metadata[0].name

  depends_on = [kubernetes_namespace.reactory]
}

# ---------------------------------------------------------------------------
# Self-hosted data services — dev only.
# Staging and production use DocumentDB and Aurora instead.
# ---------------------------------------------------------------------------
module "mongodb" {
  source = "../../../../modules/kubernetes/mongodb_selfhosted"

  namespace     = kubernetes_namespace.reactory.metadata[0].name
  secret_name   = module.external_secrets.kubernetes_secret_names["mongo"]
  database      = var.mongo_database
  storage_class = kubernetes_storage_class.gp3.metadata[0].name
  storage_size  = var.mongodb_storage_size
  image_tag     = var.mongodb_image_tag

  depends_on = [module.external_secrets, kubernetes_storage_class.gp3]
}

module "postgres" {
  source = "../../../../modules/kubernetes/postgres_selfhosted"

  namespace     = kubernetes_namespace.reactory.metadata[0].name
  secret_name   = module.external_secrets.kubernetes_secret_names["postgres"]
  database      = var.postgres_database
  storage_class = kubernetes_storage_class.gp3.metadata[0].name
  storage_size  = var.postgres_storage_size
  image_tag     = var.postgres_image_tag

  depends_on = [module.external_secrets, kubernetes_storage_class.gp3]
}

module "meilisearch" {
  source = "../../../../modules/kubernetes/meilisearch"

  namespace              = kubernetes_namespace.reactory.metadata[0].name
  master_key_secret_name = module.external_secrets.kubernetes_secret_names["meili"]
  storage_class          = kubernetes_storage_class.gp3.metadata[0].name
  storage_size           = var.meilisearch_storage_size
  meili_env              = "development"

  depends_on = [module.external_secrets, kubernetes_storage_class.gp3]
}

# ---------------------------------------------------------------------------
# Ingress controller and observability
# ---------------------------------------------------------------------------
module "alb_ingress" {
  source = "../../../modules/alb_ingress"

  cluster_name      = local.cluster.cluster_name
  aws_region        = local.cluster.aws_region
  vpc_id            = local.cluster.vpc_id
  oidc_provider_arn = local.cluster.oidc_provider_arn
  oidc_provider_url = local.cluster.oidc_provider_url
  domain_name       = var.domain_name

  tags = local.common_tags
}

module "observability" {
  source = "../../../../modules/kubernetes/observability"

  grafana_admin_password  = var.grafana_admin_password
  storage_class           = kubernetes_storage_class.gp3.metadata[0].name
  prometheus_retention    = "7d"
  prometheus_storage_size = "10Gi"
  install_jaeger          = true

  depends_on = [kubernetes_storage_class.gp3]
}

# ---------------------------------------------------------------------------
# Application
# ---------------------------------------------------------------------------
module "reactory_app" {
  source = "../../../../modules/kubernetes/reactory_app"

  namespace   = kubernetes_namespace.reactory.metadata[0].name
  environment = local.cluster.environment

  express_server_image = "${var.ecr_express_server_url}:${var.image_tag}"
  pwa_client_image     = "${var.ecr_pwa_client_url}:${var.image_tag}"

  node_env     = "development"
  api_uri_root = local.api_uri_root

  express_server = {
    replicas = 1
  }

  pwa_client = {
    replicas = 1
  }

  # Single AZ and a single replica: nothing to spread, nothing to protect from a
  # drain, and no metrics-server assumption.
  enable_hpa             = false
  enable_pdb             = false
  enable_topology_spread = false

  mongo = {
    host        = local.mongodb_host
    database    = var.mongo_database
    secret_name = module.external_secrets.kubernetes_secret_names["mongo"]
    tls         = false
  }

  postgres = {
    host        = local.postgres_host
    database    = var.postgres_database
    secret_name = module.external_secrets.kubernetes_secret_names["postgres"]
  }

  redis = {
    host        = local.cluster.valkey_endpoint
    port        = local.cluster.valkey_port
    secret_name = module.external_secrets.kubernetes_secret_names["valkey"]
    tls         = true
  }

  search = {
    provider    = "meilisearch"
    endpoint    = local.meilisearch_host
    secret_name = module.external_secrets.kubernetes_secret_names["meili"]
  }

  app_secret = {
    secret_name = module.external_secrets.kubernetes_secret_names["app"]
  }

  # ALB annotations are composed here rather than in reactory_app: the module is
  # shared with the DigitalOcean and Linode blueprints, which run ingress-nginx
  # and need an entirely different annotation set.
  ingress = {
    enabled     = true
    class_name  = "alb"
    domain_name = var.domain_name
    annotations = local.alb_annotations
  }

  labels = { "reactory.io/layer" = "workload" }

  depends_on = [
    module.external_secrets,
    module.alb_ingress,
    module.mongodb,
    module.postgres,
    module.meilisearch,
  ]
}
