# ---------------------------------------------------------------------------
# local / minikube
#
# A complete Reactory stack on minikube, built from the SAME shared modules as
# the AWS, DigitalOcean and Linode tiers. Experimenting here exercises the code
# that actually runs in the clouds — the application contract, the Secret names
# and keys, the Ingress routing are all identical.
#
# This is deliberately separate from the older `minikube/` target, which is a
# hand-rolled stack with its own database modules, Istio, host-path mounts and a
# file-sync step. That one mirrors a specific workstation setup; this one is
# self-contained and disposable.
#
# ONE LAYER, NOT TWO
#
# The cloud blueprints split cluster from workload because the kubernetes
# provider must be configured from values known at plan time. Here the cluster is
# created by the minikube CLI before Terraform runs, so ~/.kube/config already
# holds a real endpoint and there is nothing to split.
#
# Requires the cluster to exist first:
#
#   bin/minikube-up.sh
#
# then:
#
#   bin/terraform.sh apply --target=local/minikube --reactory-env=local
# ---------------------------------------------------------------------------

terraform {
  required_providers {
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

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kube_context
  }
}

locals {
  namespace = var.namespace

  # minikube ships a default StorageClass called "standard", backed by a
  # hostPath provisioner inside the VM. No StorageClass to create.
  storage_class = "standard"

  mongodb_host     = "mongodb.${local.namespace}.svc.cluster.local"
  postgres_host    = "postgres.${local.namespace}.svc.cluster.local"
  valkey_host      = "valkey.${local.namespace}.svc.cluster.local"
  meilisearch_host = "http://meilisearch.${local.namespace}.svc.cluster.local:7700"

  # minikube's ingress addon answers on the cluster IP. `minikube ip --profile
  # reactory` prints it; nip.io resolves <ip>.nip.io to that address, which gives
  # a working hostname without editing /etc/hosts.
  api_uri_root = var.api_uri_root != "" ? var.api_uri_root : "http://${var.ingress_host}"
}

resource "kubernetes_namespace" "reactory" {
  metadata {
    name = local.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "reactory.io/environment"      = "local"
    }
  }
}

# ---------------------------------------------------------------------------
# Secrets
#
# Same module the DigitalOcean and Linode blueprints use — values come from
# Terraform variables and are stored in state. That is entirely fine here: the
# state file is local and the credentials protect a throwaway cluster.
# ---------------------------------------------------------------------------
module "app_secrets" {
  source = "../../modules/kubernetes/app_secrets"

  namespace       = kubernetes_namespace.reactory.metadata[0].name
  enabled_secrets = ["mongo", "postgres", "valkey", "meili", "grafana", "app"]

  mongo_username         = var.mongo_username
  mongo_password         = var.mongo_password
  postgres_username      = var.postgres_username
  postgres_password      = var.postgres_password
  valkey_auth_token      = var.valkey_auth_token
  meilisearch_master_key = var.meilisearch_master_key
  grafana_admin_password = var.grafana_admin_password
  app_secret_key         = var.app_secret_key
}

# ---------------------------------------------------------------------------
# Data services — all in-cluster, exactly as the small cloud tiers run them
# ---------------------------------------------------------------------------
module "mongodb" {
  source = "../../modules/kubernetes/mongodb_selfhosted"

  namespace     = kubernetes_namespace.reactory.metadata[0].name
  secret_name   = module.app_secrets.kubernetes_secret_names["mongo"]
  database      = var.mongo_database
  storage_class = local.storage_class
  storage_size  = var.storage_size

  depends_on = [module.app_secrets]
}

module "postgres" {
  source = "../../modules/kubernetes/postgres_selfhosted"

  namespace     = kubernetes_namespace.reactory.metadata[0].name
  secret_name   = module.app_secrets.kubernetes_secret_names["postgres"]
  database      = var.postgres_database
  storage_class = local.storage_class
  storage_size  = var.storage_size

  depends_on = [module.app_secrets]
}

module "valkey" {
  source = "../../modules/kubernetes/valkey_selfhosted"

  namespace           = kubernetes_namespace.reactory.metadata[0].name
  secret_name         = module.app_secrets.kubernetes_secret_names["valkey"]
  persistence_enabled = false

  depends_on = [module.app_secrets]
}

module "meilisearch" {
  source = "../../modules/kubernetes/meilisearch"

  namespace              = kubernetes_namespace.reactory.metadata[0].name
  master_key_secret_name = module.app_secrets.kubernetes_secret_names["meili"]
  storage_class          = local.storage_class
  storage_size           = var.storage_size
  meili_env              = "development"

  depends_on = [module.app_secrets]
}

# ---------------------------------------------------------------------------
# Observability — optional, and off by default. The kube-prometheus-stack is
# heavy for a laptop; turn it on when that is what you are experimenting with.
# ---------------------------------------------------------------------------
module "observability" {
  count  = var.enable_observability ? 1 : 0
  source = "../../modules/kubernetes/observability"

  grafana_admin_password  = var.grafana_admin_password
  storage_class           = local.storage_class
  prometheus_retention    = "2d"
  prometheus_storage_size = "5Gi"
  install_jaeger          = var.enable_jaeger
}

# ---------------------------------------------------------------------------
# Application
#
# Ingress uses minikube's `ingress` addon, which is ingress-nginx under an
# IngressClass also called "nginx" — so the annotations match the DigitalOcean
# and Linode tiers exactly. Enable it with `minikube addons enable ingress`;
# bin/minikube-up.sh does that for you.
# ---------------------------------------------------------------------------
module "reactory_app" {
  source = "../../modules/kubernetes/reactory_app"

  namespace   = kubernetes_namespace.reactory.metadata[0].name
  environment = "local"

  express_server_image = var.express_server_image
  pwa_client_image     = var.pwa_client_image

  # Images are side-loaded with `minikube image load`, so there is nothing to
  # pull and Always would fail.
  image_pull_policy = "IfNotPresent"

  # Do not block the apply on the app rollout. The data services come up on
  # their own, so the cluster is useful for experimentation before the
  # application images have been built — without this an apply run first would
  # hang in ImagePullBackOff until the provider times out.
  wait_for_rollout = var.wait_for_app_rollout

  node_env     = "development"
  api_uri_root = local.api_uri_root

  express_server = {
    replicas       = 1
    cpu_request    = "100m"
    memory_request = "384Mi"
    cpu_limit      = "2"
    memory_limit   = "2Gi"
  }

  pwa_client = {
    replicas       = 1
    cpu_request    = "50m"
    memory_request = "64Mi"
  }

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
    tls         = false
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
    enabled     = var.enable_ingress
    class_name  = "nginx"
    domain_name = var.ingress_host
    annotations = {
      "nginx.ingress.kubernetes.io/proxy-body-size" = "32m"
    }
  }

  labels = { "reactory.io/layer" = "workload" }

  depends_on = [
    module.app_secrets,
    module.mongodb,
    module.postgres,
    module.valkey,
    module.meilisearch,
  ]
}
