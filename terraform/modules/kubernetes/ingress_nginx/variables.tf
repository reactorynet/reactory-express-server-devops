variable "namespace" {
  description = "Namespace for the ingress controller"
  type        = string
  default     = "ingress-nginx"
}

variable "ingress_class_name" {
  description = "IngressClass the controller watches; pass the same value to reactory_app"
  type        = string
  default     = "nginx"
}

variable "ingress_nginx_chart_version" {
  type    = string
  default = "4.11.3"
}

variable "replica_count" {
  description = <<-EOT
    Controller replicas. One is fine for a small tier; production wants at least
    two so a node drain does not drop all ingress.
  EOT
  type        = number
  default     = 1
}

variable "service_annotations" {
  description = <<-EOT
    Annotations on the controller's LoadBalancer Service. This is where
    provider-specific load balancer configuration goes —
    service.beta.kubernetes.io/do-loadbalancer-* on DigitalOcean,
    service.beta.kubernetes.io/linode-loadbalancer-* on Linode.
  EOT
  type        = map(string)
  default     = {}
}

variable "external_traffic_policy" {
  description = <<-EOT
    Cluster or Local. Local preserves the client source IP but health-checks
    only pass on nodes running a controller pod, so it needs replica_count to
    cover the nodes behind the load balancer.
  EOT
  type        = string
  default     = "Cluster"

  validation {
    condition     = contains(["Cluster", "Local"], var.external_traffic_policy)
    error_message = "external_traffic_policy must be Cluster or Local."
  }
}

variable "enable_metrics" {
  description = "Expose controller metrics for Prometheus scraping"
  type        = bool
  default     = true
}

variable "proxy_timeout_seconds" {
  description = "proxy-read-timeout and proxy-send-timeout. Raise for long-lived subscriptions."
  type        = number
  default     = 120
}

variable "proxy_body_size" {
  description = "Maximum request body ingress-nginx will accept (file uploads)"
  type        = string
  default     = "32m"
}

variable "controller_config" {
  description = "Extra entries merged into the ingress-nginx ConfigMap"
  type        = map(string)
  default     = {}
}

variable "cpu_request" {
  type    = string
  default = "100m"
}

variable "cpu_limit" {
  type    = string
  default = "500m"
}

variable "memory_request" {
  type    = string
  default = "128Mi"
}

variable "memory_limit" {
  type    = string
  default = "512Mi"
}

# ---------------------------------------------------------------------------
# cert-manager
# ---------------------------------------------------------------------------
variable "enable_cert_manager" {
  description = <<-EOT
    Install cert-manager and a Let's Encrypt ClusterIssuer. Pointless without a
    real domain resolving to the load balancer, because the HTTP-01 challenge
    has to be reachable — leave off for a small tier with no DNS.
  EOT
  type        = bool
  default     = false
}

variable "cert_manager_namespace" {
  type    = string
  default = "cert-manager"
}

variable "cert_manager_chart_version" {
  type    = string
  default = "v1.16.2"
}

variable "cluster_issuer_name" {
  type    = string
  default = "letsencrypt"
}

variable "acme_email" {
  description = "Contact address for Let's Encrypt expiry notices"
  type        = string
  default     = ""
}

variable "acme_server" {
  description = <<-EOT
    ACME directory URL. Defaults to the Let's Encrypt STAGING endpoint, whose
    certificates are untrusted by browsers but carry no meaningful rate limit.
    Switch to https://acme-v02.api.letsencrypt.org/directory only once the DNS
    record is confirmed working — production allows 5 duplicate certificates
    per week and a failing challenge loop exhausts that quickly.
  EOT
  type        = string
  default     = "https://acme-staging-v02.api.letsencrypt.org/directory"
}

variable "helm_timeout_seconds" {
  type    = number
  default = 600
}
