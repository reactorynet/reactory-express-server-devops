# ---------------------------------------------------------------------------
# DigitalOcean / primary / workload
#
# Adopts an EXISTING, externally-provisioned DigitalOcean Kubernetes (DOKS)
# cluster and installs the Reactory stack onto it. Unlike the small/medium/large
# tiers under digitalocean/environments/, this blueprint does NOT create the
# cluster and does NOT read a cluster layer's remote state:
#
#   * the cluster already exists (created out of band, e.g. in the DO console);
#   * the kubernetes and helm providers authenticate from a kubeconfig file, so
#     `doctl` is not required and DO tokens with a short TTL are not baked into
#     provider configuration;
#   * the digitalocean provider is used only for DNS (A records for the stack)
#     and reads DIGITALOCEAN_TOKEN from the environment.
#
# Everything else — secrets, data services, ingress/cert-manager, the
# express-server + PWA clients, and the observability stack — is composed from
# the same cloud-agnostic modules the other blueprints use.
#
# Target name: digitalocean/primary/workload
#   bin/terraform.sh plan  --target=digitalocean/primary/workload --reactory-env=digitalocean
#   bin/terraform.sh apply --target=digitalocean/primary/workload --reactory-env=digitalocean
#
# Bring-up is deliberately two-phase because the load balancer IP is not known
# until ingress-nginx has been created:
#   phase 1 — apply: data services, ingress, app, telemetry. DNS records are
#             skipped (load balancer IP is still null) and TLS is best-effort.
#   phase 2 — apply again once the LB IP is populated: A records are created and
#             cert-manager completes the ACME HTTP-01 challenges.
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.43"
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

# Reads DIGITALOCEAN_TOKEN from the environment (see .env.digitalocean).
provider "digitalocean" {}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kubeconfig_context != "" ? var.kubeconfig_context : null
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kubeconfig_context != "" ? var.kubeconfig_context : null
  }
}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------
locals {
  namespace     = var.namespace
  storage_class = var.storage_class
  host_prefix   = var.host_prefix

  # In-cluster service addresses — every data service is a pod on this cluster.
  mongodb_host     = "mongodb.${local.namespace}.svc.cluster.local"
  postgres_host    = "postgres.${local.namespace}.svc.cluster.local"
  valkey_host      = "valkey.${local.namespace}.svc.cluster.local"
  meilisearch_host = "http://meilisearch.${local.namespace}.svc.cluster.local:7700"

  # -------------------------------------------------------------------------
  # Hostnames
  #
  # base_labels are the primary names for the zone. With host_prefix empty the
  # stack takes the apex names — @ for the reactory client, api for the backend,
  # apex for BookTutor, compute for the Solar client — matching the historical
  # layout. Set host_prefix to stage a parallel set under a sub-domain instead
  # (e.g. "doks" -> doks.reactory.net, api.doks.reactory.net, ...).
  # -------------------------------------------------------------------------
  base_labels = {
    web        = ""
    api        = "api"
    booktutor  = "apex"
    compute    = "compute"
    socialeyes = "socialeyes"
    grafana    = "grafana"
    prometheus = "prometheus"
    jaeger     = "jaeger"
  }

  # "<base>.<prefix>", dropping whichever part is empty. A blank label means the
  # zone apex.
  host_labels = {
    for k, base in local.base_labels :
    k => join(".", compact([base, local.host_prefix]))
  }

  fqdn = {
    for k, l in local.host_labels :
    k => l == "" ? var.dns_zone : "${l}.${var.dns_zone}"
  }

  # DigitalOcean uses "@" as the record name for the zone apex.
  record_names = {
    for k, l in local.host_labels :
    k => l == "" ? "@" : l
  }

  # -------------------------------------------------------------------------
  # Additional PWA clients served alongside the primary reactory client.
  # -------------------------------------------------------------------------
  additional_clients = merge(
    {
      booktutor = {
        image           = "${var.image_registry}/${var.booktutor_image}:${var.image_tag}"
        domain_name     = local.fqdn.booktutor
        tls_secret_name = "reactory-tls-booktutor"
      }
    },
    var.deploy_compute_planner ? {
      compute-planner = {
        image           = "${var.image_registry}/${var.compute_planner_image}:${var.image_tag}"
        domain_name     = local.fqdn.compute
        tls_secret_name = "reactory-tls-compute-planner"
      }
    } : {},
    var.deploy_socialeyes ? {
      socialeyes = {
        image           = "${var.image_registry}/${var.socialeyes_image}:${var.image_tag}"
        domain_name     = local.fqdn.socialeyes
        tls_secret_name = "reactory-tls-socialeyes"
      }
    } : {},
  )

  # Every public host this layer is responsible for, used to drive DNS records.
  served_hosts = merge(
    {
      web       = local.fqdn.web
      api       = local.fqdn.api
      booktutor = local.fqdn.booktutor
    },
    var.deploy_compute_planner ? { compute = local.fqdn.compute } : {},
    var.deploy_socialeyes ? { socialeyes = local.fqdn.socialeyes } : {},
    var.expose_telemetry ? {
      grafana    = local.fqdn.grafana
      prometheus = local.fqdn.prometheus
      jaeger     = local.fqdn.jaeger
    } : {},
  )

  # The load balancer is provisioned asynchronously, so its IP is unknown during
  # the apply that creates ingress-nginx. DNS records are therefore gated on an
  # explicitly supplied IP (var.load_balancer_ip) rather than on this output:
  # that keeps the for_each key set statically known. Read the IP from the
  # load_balancer_ip output after the first apply and re-apply with it set.
  lb_ip       = try(module.ingress_nginx.load_balancer_ingress.ip, null)
  create_dns  = var.manage_dns && var.load_balancer_ip != ""
  express_tag = var.express_server_image_tag != "" ? var.express_server_image_tag : var.image_tag
  # cert-manager is only installed when TLS is enabled; the ClusterIssuer name
  # must match the cluster-issuer annotation the reactory_app module writes by
  # default (letsencrypt-prod).
  cluster_issuer = var.enable_tls ? module.ingress_nginx.cluster_issuer_name : null

  telemetry_issuer_annotations = var.enable_tls ? {
    "cert-manager.io/cluster-issuer" = module.ingress_nginx.cluster_issuer_name
  } : {}

  web_issuer_annotations = var.enable_tls ? {
    "cert-manager.io/cluster-issuer"                 = module.ingress_nginx.cluster_issuer_name
    "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
  } : {}
}

# ---------------------------------------------------------------------------
# Namespace
# ---------------------------------------------------------------------------
resource "kubernetes_namespace" "reactory" {
  metadata {
    name = local.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      "reactory.io/tier"             = "primary"
      "reactory.io/cluster"          = var.cluster_name
    }
  }
}

# ---------------------------------------------------------------------------
# Secrets
#
# DO has no secrets manager, so Terraform writes the Kubernetes Secrets
# directly and the values live in this layer's state. Keep the state file
# private (see README).
# ---------------------------------------------------------------------------
module "app_secrets" {
  source = "../../../modules/kubernetes/app_secrets"

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

  # GHCR images are private, so the workloads need a docker-registry secret.
  registry_auth = {
    server   = var.image_registry
    username = var.registry_username
    password = var.registry_token
  }
}

# ---------------------------------------------------------------------------
# In-cluster data services
# ---------------------------------------------------------------------------
module "mongodb" {
  source = "../../../modules/kubernetes/mongodb_selfhosted"

  namespace     = kubernetes_namespace.reactory.metadata[0].name
  secret_name   = module.app_secrets.kubernetes_secret_names["mongo"]
  database      = var.mongo_database
  storage_class = local.storage_class
  storage_size  = var.mongodb_storage_size

  depends_on = [module.app_secrets]
}

module "postgres" {
  source = "../../../modules/kubernetes/postgres_selfhosted"

  namespace     = kubernetes_namespace.reactory.metadata[0].name
  secret_name   = module.app_secrets.kubernetes_secret_names["postgres"]
  database      = var.postgres_database
  storage_class = local.storage_class
  storage_size  = var.postgres_storage_size

  depends_on = [module.app_secrets]
}

module "valkey" {
  source = "../../../modules/kubernetes/valkey_selfhosted"

  namespace   = kubernetes_namespace.reactory.metadata[0].name
  secret_name = module.app_secrets.kubernetes_secret_names["valkey"]

  # A cache that can be rebuilt does not need a volume.
  persistence_enabled = false

  depends_on = [module.app_secrets]
}

module "meilisearch" {
  source = "../../../modules/kubernetes/meilisearch"

  namespace              = kubernetes_namespace.reactory.metadata[0].name
  master_key_secret_name = module.app_secrets.kubernetes_secret_names["meili"]
  storage_class          = local.storage_class
  storage_size           = var.meilisearch_storage_size
  meili_env              = var.node_env

  depends_on = [module.app_secrets]
}

# ---------------------------------------------------------------------------
# Ingress + cert-manager
#
# One DO Load Balancer fronts ingress-nginx and serves every Ingress on the
# cluster. Prometheus is not installed at this point in the graph, so metrics
# scraping of the controller is left off here and enabled via the observability
# namespace if needed.
# ---------------------------------------------------------------------------
module "ingress_nginx" {
  source = "../../../modules/kubernetes/ingress_nginx"

  replica_count = var.ingress_replicas

  service_annotations = merge(
    {
      "service.beta.kubernetes.io/do-loadbalancer-name"                  = "${var.cluster_name}-lb"
      "service.beta.kubernetes.io/do-loadbalancer-enable-proxy-protocol" = "false"
      "service.beta.kubernetes.io/do-loadbalancer-size-unit"             = "1"
    },
    var.ingress_service_annotations,
  )

  external_traffic_policy = "Cluster"
  enable_metrics          = false

  enable_cert_manager = var.enable_tls
  acme_email          = var.acme_email
  acme_server         = var.acme_server

  # Must match the cluster-issuer annotation baked into the reactory_app
  # module's default ingress annotations.
  cluster_issuer_name = var.acme_cluster_issuer_name
}

# ---------------------------------------------------------------------------
# Application — express-server + primary PWA client + additional tenants
# ---------------------------------------------------------------------------
module "reactory_app" {
  source = "../../../modules/kubernetes/reactory_app"

  namespace   = kubernetes_namespace.reactory.metadata[0].name
  environment = "primary"

  # Clients are pinned to image_tag; the server can be pinned separately so a
  # client-only release (which is the normal case — the SPA carries the API
  # endpoint and anon credentials at compile time) does not force a server
  # rebuild. Empty falls back to image_tag.
  express_server_image = "${var.image_registry}/${var.express_server_image}:${local.express_tag}"
  pwa_client_image     = "${var.image_registry}/${var.pwa_client_image}:${var.image_tag}"
  image_pull_secrets   = [module.app_secrets.registry_secret_name]

  node_env         = var.node_env
  api_uri_root     = "https://${local.fqdn.api}"
  api_port         = var.api_port
  wait_for_rollout = var.wait_for_rollout

  # Entrypoint: run the app directly. Why not the packaged bin/run-otel.sh?
  #   1. it uses bash-only syntax but is invoked as `sh bin/run-otel.sh` (dash) → syntax error
  #   2. running it under bash works, but its `env-cmd --no-override -f ./.env …`
  #      fails on the env-cmd version the image installs (`deprecated-option`).
  # The module already injects every setting as container env, so env-cmd/.env
  # is redundant — start node directly. (OTEL tracing entrypoint is skipped;
  # metrics/traces wiring can be re-added once the image's env-cmd is pinned.)
  server_command = ["/bin/sh"]
  server_args    = ["-c", "node app/index.js"]

  express_server = {
    replicas       = var.express_server_replicas
    cpu_request    = var.express_server_cpu_request
    memory_request = var.express_server_memory_request
    cpu_limit      = var.express_server_cpu_limit
    memory_limit   = var.express_server_memory_limit

    # Probe paths now come from the workload variables, whose defaults are kept
    # honest against the deployed image (see variables.tf): liveness uses
    # /health/live, readiness still uses /health until /health/ready stops
    # returning 503 on the failing postgres check.
    liveness_path  = var.express_liveness_path
    readiness_path = var.express_readiness_path
  }

  pwa_client = {
    replicas       = var.pwa_client_replicas
    cpu_request    = "50m"
    memory_request = "64Mi"
    cpu_limit      = "500m"
    memory_limit   = "256Mi"
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

  # /reactory/reactory-data — themes, plugins, i18n, generated content.
  reactory_data_volume = {
    enabled       = true
    storage_class = local.storage_class
    storage_size  = var.reactory_data_storage_size
  }

  additional_clients = local.additional_clients

  # Application-level environment the module does not derive. Populated from
  # .env.digitalocean (TF_VAR_app_extra_env) so tenant bootstrap credentials and
  # provider keys are not hard-coded here.
  extra_env = var.app_extra_env

  ingress = {
    enabled         = true
    class_name      = module.ingress_nginx.ingress_class_name
    web_domain_name = local.fqdn.web
    api_domain_name = local.fqdn.api
    tls_secret_name = "reactory-tls"
    annotations     = local.web_issuer_annotations
  }

  labels = { "reactory.io/layer" = "primary-workload" }

  depends_on = [
    module.app_secrets,
    module.ingress_nginx,
    module.mongodb,
    module.postgres,
    module.valkey,
    module.meilisearch,
  ]
}

# ---------------------------------------------------------------------------
# Telemetry / observability — kube-prometheus-stack (Prometheus, Grafana,
# Alertmanager) + Jaeger, exposed behind the same ingress with TLS.
# ---------------------------------------------------------------------------
module "observability" {
  source = "../../../modules/kubernetes/observability"

  namespace               = var.telemetry_namespace
  grafana_admin_password  = var.grafana_admin_password
  storage_class           = local.storage_class
  prometheus_retention    = var.prometheus_retention
  prometheus_storage_size = var.prometheus_storage_size
  install_jaeger          = var.install_jaeger

  depends_on = [kubernetes_namespace.reactory]
}

resource "kubernetes_ingress_v1" "grafana" {
  count = var.expose_telemetry ? 1 : 0

  metadata {
    name      = "grafana-ingress"
    namespace = var.telemetry_namespace
    annotations = merge(
      local.telemetry_issuer_annotations,
      { "nginx.ingress.kubernetes.io/proxy-body-size" = "10m" },
    )
  }

  spec {
    ingress_class_name = module.ingress_nginx.ingress_class_name

    dynamic "tls" {
      for_each = var.enable_tls ? [1] : []
      content {
        hosts       = [local.fqdn.grafana]
        secret_name = "telemetry-tls-grafana"
      }
    }

    rule {
      host = local.fqdn.grafana
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = var.grafana_service_name
              port { number = var.grafana_service_port }
            }
          }
        }
      }
    }
  }

  depends_on = [module.observability]
}

resource "kubernetes_ingress_v1" "prometheus" {
  count = var.expose_telemetry ? 1 : 0

  metadata {
    name        = "prometheus-ingress"
    namespace   = var.telemetry_namespace
    annotations = local.telemetry_issuer_annotations
  }

  spec {
    ingress_class_name = module.ingress_nginx.ingress_class_name

    dynamic "tls" {
      for_each = var.enable_tls ? [1] : []
      content {
        hosts       = [local.fqdn.prometheus]
        secret_name = "telemetry-tls-prometheus"
      }
    }

    rule {
      host = local.fqdn.prometheus
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = var.prometheus_service_name
              port { number = var.prometheus_service_port }
            }
          }
        }
      }
    }
  }

  depends_on = [module.observability]
}

resource "kubernetes_ingress_v1" "jaeger" {
  count = var.expose_telemetry && var.install_jaeger ? 1 : 0

  metadata {
    name        = "jaeger-ingress"
    namespace   = var.telemetry_namespace
    annotations = local.telemetry_issuer_annotations
  }

  spec {
    ingress_class_name = module.ingress_nginx.ingress_class_name

    dynamic "tls" {
      for_each = var.enable_tls ? [1] : []
      content {
        hosts       = [local.fqdn.jaeger]
        secret_name = "telemetry-tls-jaeger"
      }
    }

    rule {
      host = local.fqdn.jaeger
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = var.jaeger_service_name
              port { number = var.jaeger_service_port }
            }
          }
        }
      }
    }
  }

  depends_on = [module.observability]
}

# ---------------------------------------------------------------------------
# DNS — A records for every public host, pointing at the ingress load balancer.
#
# Skipped while the load balancer IP is unknown (first apply), created on the
# next apply once the Service has been given an external address.
# ---------------------------------------------------------------------------
resource "digitalocean_record" "app" {
  for_each = local.create_dns ? local.served_hosts : {}

  domain = var.dns_zone
  type   = "A"
  name   = local.record_names[each.key]
  value  = var.load_balancer_ip
  ttl    = 300
}
