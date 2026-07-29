# ---------------------------------------------------------------------------
# module: ingress_nginx
#
# ingress-nginx plus, optionally, cert-manager with a Let's Encrypt ClusterIssuer.
#
# This is the DigitalOcean and Linode equivalent of the AWS alb_ingress module.
# Neither provider has anything like the AWS Load Balancer Controller — there is
# no controller that turns an Ingress into a cloud load balancer with a managed
# certificate. Instead:
#
#   - ingress-nginx runs in-cluster behind a Service of type LoadBalancer, and
#     the provider's cloud-controller-manager provisions one load balancer
#     (a DigitalOcean Load Balancer or a Linode NodeBalancer) for it
#   - TLS is terminated in-cluster by ingress-nginx using a certificate
#     cert-manager obtains from Let's Encrypt, rather than by the load balancer
#
# One load balancer serves every Ingress in the cluster, which matters at the
# small tier where the load balancer can cost as much as the node.
#
# service_annotations is where provider-specific load balancer configuration
# goes — see the digitalocean and linode workload layers for what each expects.
# ---------------------------------------------------------------------------

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
  }
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = var.ingress_nginx_chart_version
  namespace        = var.namespace
  create_namespace = true

  # The load balancer must exist before an Ingress can be served, and
  # cert-manager's HTTP-01 solver needs it reachable.
  wait    = true
  timeout = var.helm_timeout_seconds

  values = [yamlencode({
    controller = {
      replicaCount = var.replica_count

      service = {
        annotations = var.service_annotations
        type        = "LoadBalancer"
        # Cloud load balancers health-check the node port; preserving the client
        # source IP requires Local, but that also means only nodes running a
        # controller pod pass the check. Keep Cluster unless replica_count is at
        # least as large as the node count.
        externalTrafficPolicy = var.external_traffic_policy
      }

      # Surfaces the ingress-nginx metrics endpoint for the Prometheus stack.
      metrics = {
        enabled = var.enable_metrics
      }

      resources = {
        requests = {
          cpu    = var.cpu_request
          memory = var.memory_request
        }
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
      }

      config = merge(
        {
          # Terminate long-lived GraphQL subscriptions gracefully rather than at
          # the default 60s.
          "proxy-read-timeout"    = tostring(var.proxy_timeout_seconds)
          "proxy-send-timeout"    = tostring(var.proxy_timeout_seconds)
          "proxy-body-size"       = var.proxy_body_size
          "use-forwarded-headers" = "true"
          "enable-real-ip"        = "true"
        },
        var.controller_config,
      )
    }
  })]
}

# ---------------------------------------------------------------------------
# cert-manager
# ---------------------------------------------------------------------------
resource "helm_release" "cert_manager" {
  count = var.enable_cert_manager ? 1 : 0

  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_chart_version
  namespace        = var.cert_manager_namespace
  create_namespace = true

  # The ClusterIssuer below is a cert-manager custom resource, so the CRDs must
  # be registered and the webhook ready before it is applied.
  wait    = true
  timeout = var.helm_timeout_seconds

  set {
    name  = "crds.enabled"
    value = "true"
  }
}

# ---------------------------------------------------------------------------
# Let's Encrypt ClusterIssuer
#
# Delivered by a local Helm chart rather than kubernetes_manifest for the same
# reason as the AWS external_secrets module: kubernetes_manifest needs the CRD
# registered at *plan* time, which is impossible on a first apply.
# ---------------------------------------------------------------------------
resource "helm_release" "cluster_issuer" {
  count = var.enable_cert_manager ? 1 : 0

  name      = "letsencrypt-issuer"
  chart     = "${path.module}/chart"
  namespace = var.cert_manager_namespace

  wait    = true
  timeout = var.helm_timeout_seconds

  values = [yamlencode({
    issuer = {
      name          = var.cluster_issuer_name
      email         = var.acme_email
      server        = var.acme_server
      privateKeyRef = "${var.cluster_issuer_name}-account-key"
      ingressClass  = var.ingress_class_name
    }
  })]

  depends_on = [helm_release.cert_manager, helm_release.ingress_nginx]
}

# ---------------------------------------------------------------------------
# Read the load balancer address back off the controller Service.
#
# The Service is created by the Helm release above, so this cannot be read at
# plan time on a first apply. depends_on defers it to apply, where Terraform
# treats the result as unknown during the initial plan rather than failing.
# ---------------------------------------------------------------------------
data "kubernetes_service" "controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = var.namespace
  }

  depends_on = [helm_release.ingress_nginx]
}
