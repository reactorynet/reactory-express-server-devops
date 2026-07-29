# ---------------------------------------------------------------------------
# staging / workload layer
#
# Requires environments/staging/cluster to have been applied first.
#
# Structurally identical to production/workload, with smaller replica counts.
# All data services are managed, so there are no self-hosted database pods here —
# the difference from dev/workload is deliberate and is most of what makes
# staging a real rehearsal.
#
# See environments/dev/workload/main.tf for why the kubernetes and helm providers
# read from terraform_remote_state rather than module outputs.
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
    key    = "staging/cluster/terraform.tfstate"
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

  # DocumentDB enforces TLS and the driver resolves tlsCAFile against the process
  # working directory, so the path must be absolute. reactory_app runs an init
  # container to place the Amazon RDS trust store here.
  docdb_ca_file = "/etc/ssl/docdb/global-bundle.pem"

  api_uri_root = var.domain_name != "" ? "https://${var.domain_name}" : var.api_uri_root

  # ALB annotations. The AWS Load Balancer Controller reads these off the
  # Ingress; without a certificate it serves plain HTTP on the generated ALB
  # hostname.
  alb_annotations = merge(
    {
      "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"              = "ip"
      "alb.ingress.kubernetes.io/healthcheck-path"         = "/health"
      "alb.ingress.kubernetes.io/group.name"               = local.cluster.cluster_name
      "alb.ingress.kubernetes.io/load-balancer-attributes" = "idle_timeout.timeout_seconds=60,routing.http2.enabled=true"
    },
    module.alb_ingress.acm_certificate_arn != null ? {
      "alb.ingress.kubernetes.io/listen-ports"    = jsonencode([{ HTTP = 80 }, { HTTPS = 443 }])
      "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
      "alb.ingress.kubernetes.io/certificate-arn" = module.alb_ingress.acm_certificate_arn
      } : {
      "alb.ingress.kubernetes.io/listen-ports" = jsonencode([{ HTTP = 80 }])
    },
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
    type       = "gp3"
    encrypted  = "true"
    iops       = "3000"
    throughput = "125"
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
# Ingress controller and observability
# ---------------------------------------------------------------------------
module "alb_ingress" {
  source = "../../../modules/alb_ingress"

  cluster_name              = local.cluster.cluster_name
  aws_region                = local.cluster.aws_region
  vpc_id                    = local.cluster.vpc_id
  oidc_provider_arn         = local.cluster.oidc_provider_arn
  oidc_provider_url         = local.cluster.oidc_provider_url
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names

  tags = local.common_tags
}

module "observability" {
  source = "../../../../modules/kubernetes/observability"

  grafana_admin_password  = var.grafana_admin_password
  storage_class           = kubernetes_storage_class.gp3.metadata[0].name
  prometheus_retention    = "14d"
  prometheus_storage_size = "20Gi"
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

  # production, not staging: the point is to exercise the production code path.
  node_env     = "production"
  api_uri_root = local.api_uri_root

  express_server = {
    replicas     = var.express_server_replicas
    max_replicas = var.express_server_max_replicas
  }

  pwa_client = {
    replicas     = var.pwa_client_replicas
    max_replicas = var.pwa_client_max_replicas
  }

  # Two AZs and two replicas, so all three behaviours are worth rehearsing here.
  enable_hpa             = true
  enable_pdb             = true
  enable_topology_spread = true

  rolling_update = {
    max_surge       = "25%"
    max_unavailable = "0"
  }

  mongo = {
    host        = local.cluster.mongodb_endpoint
    port        = local.cluster.mongodb_port
    database    = var.mongo_database
    secret_name = module.external_secrets.kubernetes_secret_names["mongo"]
    tls         = true
    ca_file     = local.docdb_ca_file
    replica_set = "rs0"
    # DocumentDB does not support retryable writes.
    extra_params = "readPreference=secondaryPreferred&retryWrites=false"
  }

  postgres = {
    host        = local.cluster.postgres_endpoint
    port        = local.cluster.postgres_port
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
    provider    = "elasticsearch"
    endpoint    = local.cluster.opensearch_endpoint
    secret_name = module.external_secrets.kubernetes_secret_names["opensearch"]
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
  ]
}
