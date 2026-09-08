# ---------------------------------------------------------------------------
# Linode / small / workload layer
#
# Requires linode/environments/small/cluster.
#
# Every data service runs in-cluster: MongoDB, PostgreSQL, Valkey and
# Meilisearch are all pods.
#
# Two Linode-specific notes:
#
#   Storage — LKE ships a default StorageClass called linode-block-storage-retain,
#   which keeps the underlying volume when the PVC is deleted. That is the safer
#   default and the reason to prefer it over linode-block-storage; it also means
#   deleting a PVC leaves a volume still billing.
#
#   Auth — the LKE kubeconfig carries a long-lived service account token rather
#   than a short-lived credential, so the provider uses it directly. There is no
#   Linode equivalent of `doctl ... exec-credential`. The token is cluster-admin
#   and lives in the cluster layer's state.
#
# See aws/environments/dev/workload/main.tf for why the kubernetes and helm
# providers read from terraform_remote_state rather than module outputs.
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 4.1"
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
    key    = "linode/small/cluster/terraform.tfstate"
    region = "us-east-1"

    endpoints = {
      s3 = var.state_endpoint
    }

    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

locals {
  cluster   = data.terraform_remote_state.cluster.outputs
  namespace = "reactory"

  # LKE provides this StorageClass out of the box; "-retain" keeps the volume
  # when the PVC goes away.
  storage_class = "linode-block-storage-retain"

  # In-cluster service addresses — everything is a pod at this tier.
  mongodb_host     = "mongodb.${local.namespace}.svc.cluster.local"
  postgres_host    = "postgres.${local.namespace}.svc.cluster.local"
  valkey_host      = "valkey.${local.namespace}.svc.cluster.local"
  meilisearch_host = "http://meilisearch.${local.namespace}.svc.cluster.local:7700"

  # Domain configurations
  api_domain = var.api_domain_name != "" ? var.api_domain_name : "api.${var.domain_name}"
  web_domain = var.web_domain_name != "" ? var.web_domain_name : var.domain_name

  api_uri_root = (
    var.api_uri_root != "" ? var.api_uri_root
    : "https://${local.api_domain}"
  )

  # TLS only makes sense once a domain resolves to the NodeBalancer — the
  # HTTP-01 challenge has to be reachable from the internet.
  tls_enabled = var.domain_name != "" && var.enable_tls
}

provider "linode" {}

provider "kubernetes" {
  host                   = local.cluster.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster.cluster_ca_certificate)
  token                  = local.cluster.cluster_token
}

provider "helm" {
  kubernetes {
    host                   = local.cluster.cluster_endpoint
    cluster_ca_certificate = base64decode(local.cluster.cluster_ca_certificate)
    token                  = local.cluster.cluster_token
  }
}

resource "kubernetes_namespace" "reactory" {
  metadata {
    name = local.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "reactory.io/tier"             = local.cluster.tier
    }
  }
}

# ---------------------------------------------------------------------------
# Secrets
#
# Linode has no secrets manager, so Terraform writes the Kubernetes
# Secrets directly. The values therefore live in this layer's state — see the
# security note in modules/kubernetes/app_secrets.
# ---------------------------------------------------------------------------
module "app_secrets" {
  source = "../../../../modules/kubernetes/app_secrets"

  namespace = kubernetes_namespace.reactory.metadata[0].name

  # Self-hosted Mongo, Postgres, Valkey and Meilisearch; no OpenSearch.
  enabled_secrets = ["mongo", "postgres", "valkey", "meili", "grafana", "app"]

  mongo_username         = var.mongo_username
  mongo_password         = var.mongo_password
  postgres_username      = var.postgres_username
  postgres_password      = var.postgres_password
  valkey_auth_token      = var.valkey_auth_token
  meilisearch_master_key = var.meilisearch_master_key
  grafana_admin_password = var.grafana_admin_password
  app_secret_key         = var.app_secret_key

  registry_auth = var.registry_auth
}

# ---------------------------------------------------------------------------
# In-cluster data services
# ---------------------------------------------------------------------------
module "mongodb" {
  source = "../../../../modules/kubernetes/mongodb_selfhosted"

  namespace     = kubernetes_namespace.reactory.metadata[0].name
  secret_name   = module.app_secrets.kubernetes_secret_names["mongo"]
  database      = var.mongo_database
  storage_class = local.storage_class
  storage_size  = var.mongodb_storage_size

  depends_on = [module.app_secrets]
}

module "postgres" {
  source = "../../../../modules/kubernetes/postgres_selfhosted"

  namespace     = kubernetes_namespace.reactory.metadata[0].name
  secret_name   = module.app_secrets.kubernetes_secret_names["postgres"]
  database      = var.postgres_database
  storage_class = local.storage_class
  storage_size  = var.postgres_storage_size

  depends_on = [module.app_secrets]
}

module "valkey" {
  source = "../../../../modules/kubernetes/valkey_selfhosted"

  namespace   = kubernetes_namespace.reactory.metadata[0].name
  secret_name = module.app_secrets.kubernetes_secret_names["valkey"]

  # A cache that can be rebuilt does not need a volume.
  persistence_enabled = false

  depends_on = [module.app_secrets]
}

module "meilisearch" {
  source = "../../../../modules/kubernetes/meilisearch"

  namespace              = kubernetes_namespace.reactory.metadata[0].name
  master_key_secret_name = module.app_secrets.kubernetes_secret_names["meili"]
  storage_class          = local.storage_class
  storage_size           = var.meilisearch_storage_size
  meili_env              = "development"

  depends_on = [module.app_secrets]
}

# ---------------------------------------------------------------------------
# Ingress
#
# One NodeBalancer is created for the ingress-nginx Service and serves every
# Ingress in the cluster.
# ---------------------------------------------------------------------------
module "ingress_nginx" {
  source = "../../../../modules/kubernetes/ingress_nginx"

  replica_count = 1

  # The Linode CCM turns this Service into a NodeBalancer. TLS terminates at
  # ingress-nginx rather than the NodeBalancer, so cert-manager owns the
  # certificate lifecycle.
  service_annotations = {
    "service.beta.kubernetes.io/linode-loadbalancer-throttle" = "0"
  }

  # A single controller replica on a single node cannot satisfy Local.
  external_traffic_policy = "Cluster"

  # Prometheus is not installed at this tier, so there is nothing to scrape.
  enable_metrics = false

  enable_cert_manager = local.tls_enabled
  acme_email          = var.acme_email
  acme_server         = var.acme_server
}

# ---------------------------------------------------------------------------
# Application (Multi-Client & Dual-Domain Architecture)
# ---------------------------------------------------------------------------
module "reactory_app" {
  source = "../../../../modules/kubernetes/reactory_app"

  namespace   = kubernetes_namespace.reactory.metadata[0].name
  environment = local.cluster.tier

  express_server_image = "${var.image_registry}/${var.express_server_image}:${var.image_tag}"
  pwa_client_image     = "${var.image_registry}/${var.pwa_client_image}:${var.image_tag}"
  image_pull_secrets   = compact([module.app_secrets.registry_secret_name])

  node_env     = "production"
  api_uri_root = local.api_uri_root

  express_server = {
    replicas = 1
    # One shared node: keep requests small enough that everything schedules.
    cpu_request    = "100m"
    memory_request = "384Mi"
    cpu_limit      = "1"
    memory_limit   = "1Gi"
  }

  reactory_data_volume = {
    enabled    = true
    claim_name = "reactory-express-server-data"
  }

  pwa_client = {
    replicas       = 1
    cpu_request    = "50m"
    memory_request = "64Mi"
  }

  # Additional multi-tenant frontends (e.g. BookTutor PWA)
  additional_clients = var.booktutor_domain_name != "" ? {
    booktutor = {
      image          = "${var.image_registry}/${var.booktutor_client_image}:${var.image_tag}"
      domain_name    = var.booktutor_domain_name
      replicas       = 1
      cpu_request    = "50m"
      memory_request = "64Mi"
    }
  } : {}

  # One node, one replica: nothing to spread, nothing to protect from a drain,
  # and no metrics-server to autoscale from.
  enable_hpa             = false
  enable_pdb             = false
  enable_topology_spread = false

  mongo = {
    host        = local.mongodb_host
    database    = var.mongo_database
    secret_name = module.app_secrets.kubernetes_secret_names["mongo"]
    tls         = false
  }

  postgres = {
    host        = local.postgres_host
    database    = var.postgres_database
    secret_name = module.app_secrets.kubernetes_secret_names["postgres"]
  }

  redis = {
    host        = local.valkey_host
    secret_name = module.app_secrets.kubernetes_secret_names["valkey"]
    # The in-cluster Valkey pod does not serve TLS, unlike DigitalOcean's
    # managed Valkey which mandates it.
    tls = false
  }

  search = {
    provider    = "meilisearch"
    endpoint    = local.meilisearch_host
    secret_name = module.app_secrets.kubernetes_secret_names["meili"]
  }

  app_secret = {
    secret_name = module.app_secrets.kubernetes_secret_names["app"]
  }

  ingress = {
    enabled         = true
    class_name      = module.ingress_nginx.ingress_class_name
    web_domain_name = local.web_domain
    api_domain_name = local.api_domain
    domain_name     = var.domain_name
    annotations = merge(
      {
        "nginx.ingress.kubernetes.io/proxy-body-size"    = "32m"
        "nginx.ingress.kubernetes.io/proxy-read-timeout" = "3600"
        "nginx.ingress.kubernetes.io/proxy-send-timeout" = "3600"
        "nginx.ingress.kubernetes.io/proxy-buffering"    = "off"
      },
      local.tls_enabled ? {
        "cert-manager.io/cluster-issuer"                 = module.ingress_nginx.cluster_issuer_name
        "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
      } : {},
    )
    tls_secret_name = local.tls_enabled ? "reactory-tls" : null
  }

  labels = { "reactory.io/layer" = "workload" }

  depends_on = [
    module.app_secrets,
    module.ingress_nginx,
    module.mongodb,
    module.postgres,
    module.valkey,
    module.meilisearch,
  ]
}
