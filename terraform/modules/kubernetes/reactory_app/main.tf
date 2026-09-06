# ---------------------------------------------------------------------------
# module: reactory_app
#
# The Reactory workloads — express-server and pwa-client — with their Services,
# optional HPAs and PDBs, Dual-Domain Ingress (Web *-web.* and API *-api.*),
# and support for multi-tenant additional PWA clients (e.g. BookTutor).
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
  }
}

locals {
  server_name = "reactory-express-server"
  client_name = "reactory-pwa-client"

  common_labels = merge(var.labels, {
    "app.kubernetes.io/part-of"    = "reactory"
    "app.kubernetes.io/managed-by" = "terraform"
    "reactory.io/environment"      = var.environment
  })

  server_labels = merge(local.common_labels, { app = local.server_name })
  client_labels = merge(local.common_labels, { app = local.client_name })

  needs_ca_bundle = var.mongo.tls && var.mongo.ca_file != null
  ca_dir          = local.needs_ca_bundle ? dirname(var.mongo.ca_file) : ""

  # -------------------------------------------------------------------------
  # Hostname & Dual-Domain Topology Resolution
  # -------------------------------------------------------------------------
  web_domain = var.ingress.web_domain_name != "" ? var.ingress.web_domain_name : (var.ingress.domain_name != "" ? var.ingress.domain_name : "")
  api_domain = var.ingress.api_domain_name != "" ? var.ingress.api_domain_name : (var.ingress.domain_name != "" ? var.ingress.domain_name : "")

  is_dual_domain = (
    var.ingress.web_domain_name != "" &&
    var.ingress.api_domain_name != "" &&
    var.ingress.web_domain_name != var.ingress.api_domain_name
  )

  api_url = local.api_domain != "" ? "https://${local.api_domain}" : var.api_uri_root
  web_url = local.web_domain != "" ? "https://${local.web_domain}" : var.api_uri_root

  # -------------------------------------------------------------------------
  # Comprehensive CORS Whitelist (HTTP + HTTPS for all tenants)
  # -------------------------------------------------------------------------
  all_whitelist_origins = distinct(compact(concat(
    [
      "http://localhost:3000",
      "http://localhost:3004",
      "http://localhost:4000",
      "http://reactory.net",
      "https://reactory.net",
      "http://www.reactory.net",
      "https://www.reactory.net",
      "http://app.reactory.net",
      "https://app.reactory.net",
      "http://api.reactory.net",
      "https://api.reactory.net",
      "http://apex.reactory.net",
      "https://apex.reactory.net",
      "http://booktutor.reactory.net",
      "https://booktutor.reactory.net",
      local.web_url,
      local.api_url,
      "http://${local.web_domain}",
      "https://${local.web_domain}",
      "http://${local.api_domain}",
      "https://${local.api_domain}",
    ],
    [for k, v in var.additional_clients : "http://${v.domain_name}" if v.domain_name != ""],
    [for k, v in var.additional_clients : "https://${v.domain_name}" if v.domain_name != ""],
  )))

  # -------------------------------------------------------------------------
  # MONGOOSE connection string
  # -------------------------------------------------------------------------
  mongo_query = join("", concat(
    ["?authSource=${var.mongo.auth_source}"],
    var.mongo.tls ? ["&tls=true"] : [],
    var.mongo.ca_file != null ? ["&tlsCAFile=${var.mongo.ca_file}"] : [],
    var.mongo.replica_set != null ? ["&replicaSet=${var.mongo.replica_set}"] : [],
    var.mongo.extra_params != "" ? ["&${var.mongo.extra_params}"] : [],
  ))

  mongoose_uri = join("", [
    "mongodb://$(MONGO_USER):$(MONGO_PASSWORD)@",
    var.mongo.host, ":", tostring(var.mongo.port), "/", var.mongo.database,
    local.mongo_query,
  ])

  # -------------------------------------------------------------------------
  # Environment list
  # -------------------------------------------------------------------------
  env_paths = [
    { name = "REACTORY_HOME", value = var.reactory_paths.home, secret_name = null, secret_key = null },
    { name = "REACTORY_DATA", value = var.reactory_paths.data, secret_name = null, secret_key = null },
    { name = "APP_DATA_ROOT", value = var.reactory_paths.data, secret_name = null, secret_key = null },
    { name = "APPLICATION_ROOT", value = "app", secret_name = null, secret_key = null },
    { name = "REACTORY_SERVER", value = var.reactory_paths.server, secret_name = null, secret_key = null },
    { name = "REACTORY_CLIENT", value = var.reactory_paths.client, secret_name = null, secret_key = null },
    { name = "REACTORY_PLUGINS", value = var.reactory_paths.plugins, secret_name = null, secret_key = null },
  ]

  env_runtime = [
    { name = "NODE_ENV", value = var.node_env, secret_name = null, secret_key = null },
    { name = "MODE", value = var.node_env, secret_name = null, secret_key = null },
    { name = "API_PORT", value = tostring(var.api_port), secret_name = null, secret_key = null },
    { name = "API_URI_ROOT", value = local.api_url, secret_name = null, secret_key = null },
    { name = "CDN_ROOT", value = "${local.api_url}/cdn", secret_name = null, secret_key = null },
    { name = "SSE_URI_ROOT", value = local.api_url, secret_name = null, secret_key = null },
    { name = "REACTORY_SITE_URL", value = local.web_url, secret_name = null, secret_key = null },
    { name = "REACTORY_APPLICATION_URL", value = local.web_url, secret_name = null, secret_key = null },
    { name = "REACTORY_APP_WHITELIST", value = join(",", local.all_whitelist_origins), secret_name = null, secret_key = null },
    { name = "REACTORY_STREAMING_FANOUT", value = "on", secret_name = null, secret_key = null },
    { name = "I18N_NS", value = "reactory,reactor,booktutor,zepz-engineer", secret_name = null, secret_key = null },
  ]

  env_mongo = [
    { name = "MONGO_USER", value = null, secret_name = var.mongo.secret_name, secret_key = var.mongo.username_key },
    { name = "MONGO_PASSWORD", value = null, secret_name = var.mongo.secret_name, secret_key = var.mongo.password_key },
    { name = "MONGOOSE", value = local.mongoose_uri, secret_name = null, secret_key = null },
  ]

  env_postgres = [
    { name = "REACTORY_POSTGRES_HOST", value = var.postgres.host, secret_name = null, secret_key = null },
    { name = "REACTORY_POSTGRES_PORT", value = tostring(var.postgres.port), secret_name = null, secret_key = null },
    { name = "REACTORY_POSTGRES_DB", value = var.postgres.database, secret_name = null, secret_key = null },
    { name = "REACTORY_POSTGRES_USER", value = null, secret_name = var.postgres.secret_name, secret_key = var.postgres.username_key },
    { name = "REACTORY_POSTGRES_PASSWORD", value = null, secret_name = var.postgres.secret_name, secret_key = var.postgres.password_key },
  ]

  env_redis = [
    { name = "REACTORY_REDIS_HOST", value = var.redis.host, secret_name = null, secret_key = null },
    { name = "REACTORY_REDIS_PORT", value = tostring(var.redis.port), secret_name = null, secret_key = null },
    { name = "REACTORY_REDIS_DB", value = tostring(var.redis.db), secret_name = null, secret_key = null },
    { name = "REACTORY_REDIS_PASSWORD", value = null, secret_name = var.redis.secret_name, secret_key = var.redis.password_key },
    { name = "REACTORY_REDIS_TLS", value = tostring(var.redis.tls), secret_name = null, secret_key = null },
  ]

  env_search = var.search.provider == "meilisearch" ? [
    { name = "REACTORY_SEARCH_PROVIDER", value = "meilisearch", secret_name = null, secret_key = null },
    { name = "MEILISEARCH_HOST", value = var.search.endpoint, secret_name = null, secret_key = null },
    { name = "MEILISEARCH_MASTER_KEY", value = null, secret_name = var.search.secret_name, secret_key = var.search.master_key_key },
    ] : [
    { name = "REACTORY_SEARCH_PROVIDER", value = "elasticsearch", secret_name = null, secret_key = null },
    { name = "ELASTICSEARCH_NODE", value = var.search.endpoint, secret_name = null, secret_key = null },
    { name = "ELASTICSEARCH_USERNAME", value = null, secret_name = var.search.secret_name, secret_key = var.search.username_key },
    { name = "ELASTICSEARCH_PASSWORD", value = null, secret_name = var.search.secret_name, secret_key = var.search.password_key },
  ]

  env_secrets = [
    { name = "SECRET_SAUCE", value = null, secret_name = var.app_secret.secret_name, secret_key = var.app_secret.key },
    { name = "SESSION_SECRET", value = null, secret_name = var.app_secret.secret_name, secret_key = var.app_secret.key },
  ]

  env_extra = [
    for k, v in var.extra_env :
    { name = k, value = v, secret_name = null, secret_key = null }
  ]

  server_env = concat(
    local.env_paths,
    local.env_runtime,
    local.env_mongo,
    local.env_postgres,
    local.env_redis,
    local.env_search,
    local.env_secrets,
    local.env_extra,
  )

  # -------------------------------------------------------------------------
  # Ingress Defaults
  # -------------------------------------------------------------------------
  default_api_annotations = {
    "cert-manager.io/cluster-issuer"                 = "letsencrypt-prod"
    "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
    "nginx.ingress.kubernetes.io/proxy-body-size"    = "64m"
    "nginx.ingress.kubernetes.io/proxy-buffering"    = "off"
    "nginx.ingress.kubernetes.io/proxy-read-timeout" = "3600"
    "nginx.ingress.kubernetes.io/proxy-send-timeout" = "3600"
    "nginx.ingress.kubernetes.io/websocket-services" = local.server_name
  }

  default_web_annotations = {
    "cert-manager.io/cluster-issuer"                 = "letsencrypt-prod"
    "nginx.ingress.kubernetes.io/force-ssl-redirect" = "true"
    "nginx.ingress.kubernetes.io/proxy-body-size"    = "10m"
  }
}

# ---------------------------------------------------------------------------
# express-server
# ---------------------------------------------------------------------------
resource "kubernetes_deployment" "express_server" {
  metadata {
    name      = local.server_name
    namespace = var.namespace
    labels    = local.server_labels
  }

  wait_for_rollout = var.wait_for_rollout

  spec {
    replicas = var.express_server.replicas

    selector {
      match_labels = { app = local.server_name }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = var.rolling_update.max_surge
        max_unavailable = var.rolling_update.max_unavailable
      }
    }

    template {
      metadata {
        labels = local.server_labels
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = tostring(var.api_port)
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        dynamic "image_pull_secrets" {
          for_each = var.image_pull_secrets
          content {
            name = image_pull_secrets.value
          }
        }

        dynamic "topology_spread_constraint" {
          for_each = var.enable_topology_spread ? [1] : []
          content {
            max_skew           = 1
            topology_key       = "topology.kubernetes.io/zone"
            when_unsatisfiable = "DoNotSchedule"
            label_selector {
              match_labels = { app = local.server_name }
            }
          }
        }

        dynamic "init_container" {
          for_each = local.needs_ca_bundle ? [1] : []
          content {
            name              = "fetch-db-ca-bundle"
            image             = var.ca_bundle_init_image
            image_pull_policy = var.image_pull_policy
            command           = ["sh", "-c"]
            args = [
              "set -e; curl -fsSL --retry 5 --retry-delay 3 -o ${var.mongo.ca_file} ${var.ca_bundle_url}; test -s ${var.mongo.ca_file}"
            ]

            resources {
              requests = { cpu = "10m", memory = "32Mi" }
              limits   = { cpu = "200m", memory = "128Mi" }
            }

            volume_mount {
              name       = "db-ca-bundle"
              mount_path = local.ca_dir
            }
          }
        }

        container {
          name              = local.server_name
          image             = var.express_server_image
          image_pull_policy = var.image_pull_policy
          command           = var.server_command
          args              = var.server_args

          dynamic "env" {
            for_each = local.server_env
            content {
              name  = env.value.name
              value = env.value.secret_name == null ? env.value.value : null

              dynamic "value_from" {
                for_each = env.value.secret_name == null ? [] : [1]
                content {
                  secret_key_ref {
                    name = env.value.secret_name
                    key  = env.value.secret_key
                  }
                }
              }
            }
          }

          port {
            container_port = var.api_port
            name           = "http"
          }

          resources {
            requests = {
              cpu    = var.express_server.cpu_request
              memory = var.express_server.memory_request
            }
            limits = {
              cpu    = var.express_server.cpu_limit
              memory = var.express_server.memory_limit
            }
          }

          dynamic "volume_mount" {
            for_each = local.needs_ca_bundle ? [1] : []
            content {
              name       = "db-ca-bundle"
              mount_path = local.ca_dir
              read_only  = true
            }
          }

          dynamic "volume_mount" {
            for_each = var.reactory_data_volume.enabled ? [1] : []
            content {
              name       = "reactory-data"
              mount_path = var.reactory_paths.data
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = var.api_port
            }
            initial_delay_seconds = 180
            period_seconds        = 20
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = var.api_port
            }
            initial_delay_seconds = 60
            period_seconds        = 10
            timeout_seconds       = 5
            success_threshold     = 1
            failure_threshold     = 6
          }
        }

        dynamic "volume" {
          for_each = local.needs_ca_bundle ? [1] : []
          content {
            name = "db-ca-bundle"
            empty_dir {}
          }
        }

        dynamic "volume" {
          for_each = var.reactory_data_volume.enabled ? [1] : []
          content {
            name = "reactory-data"
            persistent_volume_claim {
              claim_name = var.reactory_data_volume.claim_name != "" ? var.reactory_data_volume.claim_name : "${local.server_name}-data"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "express_server" {
  metadata {
    name      = local.server_name
    namespace = var.namespace
    labels    = local.server_labels
  }
  spec {
    selector = { app = local.server_name }
    port {
      name        = "http"
      port        = var.api_port
      target_port = var.api_port
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "express_server" {
  count = var.enable_hpa ? 1 : 0

  metadata {
    name      = "${local.server_name}-hpa"
    namespace = var.namespace
    labels    = local.server_labels
  }
  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.express_server.metadata[0].name
    }
    min_replicas = var.express_server.replicas
    max_replicas = var.express_server.max_replicas

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

resource "kubernetes_pod_disruption_budget_v1" "express_server" {
  count = var.enable_pdb ? 1 : 0

  metadata {
    name      = "${local.server_name}-pdb"
    namespace = var.namespace
    labels    = local.server_labels
  }
  spec {
    min_available = 1
    selector {
      match_labels = { app = local.server_name }
    }
  }
}

# ---------------------------------------------------------------------------
# pwa-client (Primary / Default Reactory Management Client)
# ---------------------------------------------------------------------------
resource "kubernetes_deployment" "pwa_client" {
  metadata {
    name      = local.client_name
    namespace = var.namespace
    labels    = local.client_labels
  }

  wait_for_rollout = var.wait_for_rollout

  spec {
    replicas = var.pwa_client.replicas

    selector {
      match_labels = { app = local.client_name }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = var.rolling_update.max_surge
        max_unavailable = var.rolling_update.max_unavailable
      }
    }

    template {
      metadata {
        labels = local.client_labels
      }

      spec {
        dynamic "image_pull_secrets" {
          for_each = var.image_pull_secrets
          content {
            name = image_pull_secrets.value
          }
        }

        dynamic "topology_spread_constraint" {
          for_each = var.enable_topology_spread ? [1] : []
          content {
            max_skew           = 1
            topology_key       = "topology.kubernetes.io/zone"
            when_unsatisfiable = "DoNotSchedule"
            label_selector {
              match_labels = { app = local.client_name }
            }
          }
        }

        container {
          name              = local.client_name
          image             = var.pwa_client_image
          image_pull_policy = var.image_pull_policy

          port {
            container_port = 80
            name           = "http"
          }

          resources {
            requests = {
              cpu    = var.pwa_client.cpu_request
              memory = var.pwa_client.memory_request
            }
            limits = {
              cpu    = var.pwa_client.cpu_limit
              memory = var.pwa_client.memory_limit
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 15
            period_seconds        = 20
            timeout_seconds       = 5
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 5
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "pwa_client" {
  metadata {
    name      = local.client_name
    namespace = var.namespace
    labels    = local.client_labels
  }
  spec {
    selector = { app = local.client_name }
    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "pwa_client" {
  count = var.enable_hpa ? 1 : 0

  metadata {
    name      = "${local.client_name}-hpa"
    namespace = var.namespace
    labels    = local.client_labels
  }
  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.pwa_client.metadata[0].name
    }
    min_replicas = var.pwa_client.replicas
    max_replicas = var.pwa_client.max_replicas

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

resource "kubernetes_pod_disruption_budget_v1" "pwa_client" {
  count = var.enable_pdb ? 1 : 0

  metadata {
    name      = "${local.client_name}-pdb"
    namespace = var.namespace
    labels    = local.client_labels
  }
  spec {
    min_available = 1
    selector {
      match_labels = { app = local.client_name }
    }
  }
}

# ---------------------------------------------------------------------------
# Additional Multi-Tenant Clients (e.g. BookTutor)
# ---------------------------------------------------------------------------
resource "kubernetes_deployment" "additional_pwa_client" {
  for_each = var.additional_clients

  metadata {
    name      = "${each.key}-pwa-client"
    namespace = var.namespace
    labels    = merge(local.common_labels, { app = "${each.key}-pwa-client" })
  }

  wait_for_rollout = var.wait_for_rollout

  spec {
    replicas = each.value.replicas

    selector {
      match_labels = { app = "${each.key}-pwa-client" }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = var.rolling_update.max_surge
        max_unavailable = var.rolling_update.max_unavailable
      }
    }

    template {
      metadata {
        labels = merge(local.common_labels, { app = "${each.key}-pwa-client" })
      }

      spec {
        dynamic "image_pull_secrets" {
          for_each = var.image_pull_secrets
          content {
            name = image_pull_secrets.value
          }
        }

        container {
          name              = "${each.key}-pwa-client"
          image             = each.value.image
          image_pull_policy = var.image_pull_policy

          port {
            container_port = 80
            name           = "http"
          }

          resources {
            requests = {
              cpu    = each.value.cpu_request
              memory = each.value.memory_request
            }
            limits = {
              cpu    = each.value.cpu_limit
              memory = each.value.memory_limit
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 15
            period_seconds        = 20
            timeout_seconds       = 5
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 5
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "additional_pwa_client" {
  for_each = var.additional_clients

  metadata {
    name      = "${each.key}-pwa-client"
    namespace = var.namespace
    labels    = merge(local.common_labels, { app = "${each.key}-pwa-client" })
  }
  spec {
    selector = { app = "${each.key}-pwa-client" }
    port {
      name        = "http"
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
    type = "ClusterIP"
  }
}

# ---------------------------------------------------------------------------
# DUAL-DOMAIN INGRESS ARCHITECTURE
# 1. API Ingress — routes all paths on api_domain to express-server
# 2. Web Ingress — routes all paths on web_domain to pwa-client (SPA)
# 3. Additional Web Ingresses — routes each additional tenant domain
# Fallback: Single Ingress for legacy single-domain setups
# ---------------------------------------------------------------------------

# 1. API Ingress (Dual-Domain mode)
resource "kubernetes_ingress_v1" "api" {
  count = var.ingress.enabled && local.is_dual_domain ? 1 : 0

  metadata {
    name      = "${local.server_name}-ingress"
    namespace = var.namespace
    labels    = local.common_labels
    annotations = merge(
      local.default_api_annotations,
      var.ingress.annotations,
      var.ingress.api_annotations
    )
  }

  spec {
    ingress_class_name = var.ingress.class_name

    tls {
      hosts       = [local.api_domain]
      secret_name = "${var.ingress.tls_secret_name}-api"
    }

    rule {
      host = local.api_domain
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.express_server.metadata[0].name
              port {
                number = var.api_port
              }
            }
          }
        }
      }
    }
  }
}

# 2. Web Client Ingress (Dual-Domain mode)
resource "kubernetes_ingress_v1" "web" {
  count = var.ingress.enabled && local.is_dual_domain ? 1 : 0

  metadata {
    name      = "${local.client_name}-ingress"
    namespace = var.namespace
    labels    = local.common_labels
    annotations = merge(
      local.default_web_annotations,
      var.ingress.annotations,
      var.ingress.web_annotations
    )
  }

  spec {
    ingress_class_name = var.ingress.class_name

    tls {
      hosts       = [local.web_domain]
      secret_name = "${var.ingress.tls_secret_name}-web"
    }

    rule {
      host = local.web_domain
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.pwa_client.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

# 3. Additional Web Client Ingresses (Multi-Client)
resource "kubernetes_ingress_v1" "additional_web" {
  for_each = {
    for k, v in var.additional_clients : k => v
    if var.ingress.enabled && v.domain_name != ""
  }

  metadata {
    name      = "${each.key}-pwa-client-ingress"
    namespace = var.namespace
    labels    = local.common_labels
    annotations = merge(
      local.default_web_annotations,
      var.ingress.annotations,
      each.value.annotations
    )
  }

  spec {
    ingress_class_name = var.ingress.class_name

    tls {
      hosts       = [each.value.domain_name]
      secret_name = each.value.tls_secret_name != null && each.value.tls_secret_name != "" ? each.value.tls_secret_name : "${var.ingress.tls_secret_name}-${each.key}"
    }

    rule {
      host = each.value.domain_name
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.additional_pwa_client[each.key].metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

# 4. Single Ingress Fallback (Legacy single-domain mode)
resource "kubernetes_ingress_v1" "reactory" {
  count = var.ingress.enabled && !local.is_dual_domain ? 1 : 0

  metadata {
    name        = "reactory-ingress"
    namespace   = var.namespace
    labels      = local.common_labels
    annotations = var.ingress.annotations
  }

  spec {
    ingress_class_name = var.ingress.class_name

    dynamic "tls" {
      for_each = var.ingress.tls_secret_name != null && var.ingress.tls_secret_name != "" && local.web_domain != "" ? [1] : []
      content {
        hosts       = [local.web_domain]
        secret_name = var.ingress.tls_secret_name
      }
    }

    rule {
      host = local.web_domain != "" ? local.web_domain : null

      http {
        dynamic "path" {
          for_each = [
            var.ingress.api_path_prefix,
            "/cdn",
            "/graph",
            "/graphql",
            "/health",
            "/telemetry",
            "/stream",
            "/auth",
            "/login",
            "/logout",
            "/user",
            "/amq",
            "/pdf",
            "/resources",
            "/reactory",
            "/search"
          ]
          content {
            path      = path.value
            path_type = "Prefix"
            backend {
              service {
                name = kubernetes_service.express_server.metadata[0].name
                port {
                  number = var.api_port
                }
              }
            }
          }
        }

        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.pwa_client.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
