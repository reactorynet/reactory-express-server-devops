# ---------------------------------------------------------------------------
# module: reactory_app
#
# The Reactory workloads — express-server and pwa-client — with their Services,
# optional HPAs and PDBs, and the shared ALB Ingress.
#
# This module owns the application's environment contract. Every blueprint
# composes it from the same code, so dev, staging and production cannot drift
# apart on variable names. The names here are verifiable in the server source:
#
#   MONGOOSE                 src/models/mongoose/index.ts, src/constants/index.ts
#   REACTORY_POSTGRES_*      src/database/postgres/ConnectionFactory.ts
#   REACTORY_REDIS_*         src/modules/reactory-core/services/RedisService.ts
#   MEILISEARCH_*            services/search/providers/MeiliSearchProvider.ts
#   ELASTICSEARCH_*          services/search/providers/ElasticSearchProvider.ts
#   REACTORY_SEARCH_PROVIDER services/ReactorySearchService.ts
#   SECRET_SAUCE             src/express/middleware/ReactorySession.ts
#   API_PORT / API_URI_ROOT  src/express/server.ts
#
# SERVER_IP is deliberately never set: server.ts passes it straight to
# httpServer.listen(), and leaving it unset binds to all interfaces, which is
# what probes and Services require.
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

  # DocumentDB requires TLS against the Amazon RDS trust store. The bundle is
  # fetched into an emptyDir rather than baked into the application image.
  needs_ca_bundle = var.mongo.tls && var.mongo.ca_file != null
  ca_dir          = local.needs_ca_bundle ? dirname(var.mongo.ca_file) : ""

  # -------------------------------------------------------------------------
  # MONGOOSE connection string.
  #
  # $(MONGO_USER)/$(MONGO_PASSWORD) are expanded by the kubelet, so the
  # credentials never appear in the pod spec. This only works because both are
  # declared before MONGOOSE in the env list below.
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
  # Environment list.
  #
  # ORDER IS SIGNIFICANT. Kubernetes expands $(VAR) references only against
  # variables declared EARLIER in the same list, and the provider models `env`
  # as an ordered list, so this sequence is preserved verbatim. MONGO_USER and
  # MONGO_PASSWORD must precede MONGOOSE.
  #
  # Every entry carries the same four attributes so the list has a single
  # unifiable type: `value` for literals, `secret_name`/`secret_key` for
  # Secret-backed values.
  # -------------------------------------------------------------------------
  env_paths = [
    { name = "REACTORY_HOME", value = var.reactory_paths.home, secret_name = null, secret_key = null },
    { name = "REACTORY_DATA", value = var.reactory_paths.data, secret_name = null, secret_key = null },
    { name = "REACTORY_SERVER", value = var.reactory_paths.server, secret_name = null, secret_key = null },
    { name = "REACTORY_CLIENT", value = var.reactory_paths.client, secret_name = null, secret_key = null },
    { name = "REACTORY_PLUGINS", value = var.reactory_paths.plugins, secret_name = null, secret_key = null },
  ]

  env_runtime = [
    { name = "NODE_ENV", value = var.node_env, secret_name = null, secret_key = null },
    { name = "MODE", value = var.node_env, secret_name = null, secret_key = null },
    { name = "API_PORT", value = tostring(var.api_port), secret_name = null, secret_key = null },
    { name = "API_URI_ROOT", value = var.api_uri_root, secret_name = null, secret_key = null },
    { name = "CDN_ROOT", value = "${var.api_uri_root}/cdn", secret_name = null, secret_key = null },
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
    # ElastiCache mandates transit encryption whenever an AUTH token is set.
    # See readme.md "Known gaps" — the Redis client does not honour this yet.
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
  # Ingress annotations
  # -------------------------------------------------------------------------
  tls_enabled = var.ingress.certificate_arn != null && var.ingress.certificate_arn != ""

  ingress_annotations = merge(
    {
      "alb.ingress.kubernetes.io/scheme"           = var.ingress.scheme
      "alb.ingress.kubernetes.io/target-type"      = "ip"
      "alb.ingress.kubernetes.io/healthcheck-path" = var.ingress.healthcheck_path
    },
    var.ingress.group_name != null ? {
      "alb.ingress.kubernetes.io/group.name" = var.ingress.group_name
    } : {},
    local.tls_enabled ? {
      "alb.ingress.kubernetes.io/listen-ports"    = jsonencode([{ HTTP = 80 }, { HTTPS = 443 }])
      "alb.ingress.kubernetes.io/ssl-redirect"    = "443"
      "alb.ingress.kubernetes.io/certificate-arn" = var.ingress.certificate_arn
      } : {
      "alb.ingress.kubernetes.io/listen-ports" = jsonencode([{ HTTP = 80 }])
    },
    var.ingress.extra_annotations,
  )
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

          liveness_probe {
            http_get {
              path = "/health"
              port = var.api_port
            }
            initial_delay_seconds = 60
            period_seconds        = 20
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = var.api_port
            }
            initial_delay_seconds = 20
            period_seconds        = 10
            timeout_seconds       = 5
            success_threshold     = 1
            failure_threshold     = 3
          }
        }

        dynamic "volume" {
          for_each = local.needs_ca_bundle ? [1] : []
          content {
            name = "db-ca-bundle"
            empty_dir {}
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

# A rolling update alone does not protect against node drains; a PDB keeps at
# least one replica serving during voluntary disruption.
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
# pwa-client
# ---------------------------------------------------------------------------
resource "kubernetes_deployment" "pwa_client" {
  metadata {
    name      = local.client_name
    namespace = var.namespace
    labels    = local.client_labels
  }

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
# Ingress — /api to the server, everything else to the client
# ---------------------------------------------------------------------------
resource "kubernetes_ingress_v1" "reactory" {
  count = var.ingress.enabled ? 1 : 0

  metadata {
    name        = "reactory-ingress"
    namespace   = var.namespace
    labels      = local.common_labels
    annotations = local.ingress_annotations
  }

  spec {
    # ingressClassName replaces the deprecated kubernetes.io/ingress.class
    # annotation, which the AWS Load Balancer Controller no longer honours.
    ingress_class_name = var.ingress.class_name

    rule {
      host = var.ingress.domain_name != "" ? var.ingress.domain_name : null

      http {
        path {
          path      = var.ingress.api_path_prefix
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
