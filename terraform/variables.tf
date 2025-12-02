variable "db_password" {
  type        = string
  description = "DB administrator password"
  sensitive   = true
}

variable "db_username" {
  type        = string
  description = "DB username"
}

variable "database_name" {
  description = "DB Name"
  type        = string
}

variable "route53_zone_id" {
  type        = string
  description = "Route53 Zone ID"
}

variable "route53_zone_name" {
  type        = string
  description = "Route53 Zone Name"
}

variable "aws_region" {
  type        = string
  description = "AWS region for the demo deployment"
  default     = ""
}

variable "cert_arn" {
  type        = string
  description = "Route53 Hosted Zone ID AWS Certificate Manager ARN"
}

variable "environment" {
  type        = string
  description = "Environment workspace"
}

variable "keycloak_username" {
  type        = string
  description = "Keycloak username"
}

variable "keycloak_password" {
  description = "Keycloak Password"
  type        = string
  sensitive   = true
}

variable "keycloak_namespace" {
  description = "Namespace for Keycloak resources"
  type        = string
  default     = "keycloak"
}

variable "cluster_version" {
  type        = string
  description = "EKS cluster version"
}

variable "alb_controller_chart_version" {
  type        = string
  description = "Pinned AWS Load Balancer Controller Helm chart version"
  default     = "1.10.0"
}

variable "alb_controller_image_tag" {
  type        = string
  description = "AWS Load Balancer Controller image tag"
  default     = "v2.10.0"
}

variable "keycloak_chart_version" {
  type        = string
  description = "Pinned Keycloak Helm chart version for the demo"
  default     = "26.0.3"
}

variable "keycloak_image_tag" {
  type        = string
  description = "Keycloak container image tag to deploy (avoid 'latest' for deterministic demos)"
  default     = "26.0.3"
}

variable "keycloak_hostname" {
  type        = string
  description = "Fully qualified hostname for Keycloak ingress (e.g., keycloak.demo.example.com)"
}

variable "keycloak_admin_secret_name" {
  type        = string
  description = "Name of the Kubernetes secret containing Keycloak admin credentials"
  default     = "keycloak-admin-credentials"
}

variable "keycloak_db_secret_name" {
  type        = string
  description = "Name of the Kubernetes secret containing database credentials for Keycloak"
  default     = "keycloak-db-credentials"
}

variable "alb_log_bucket" {
  type        = string
  description = "S3 bucket name for ALB access logs (must exist for the demo)"
}

variable "alb_log_prefix" {
  type        = string
  description = "Prefix to use for ALB access logs in the S3 bucket"
  default     = "keycloak-demo"
}

variable "alb_ingress_group_name" {
  type        = string
  description = "Ingress group name for the demo ALB so sibling services on other subdomains can share the same load balancer"
  default     = "appdev-shared"
}

variable "alb_ingress_healthcheck_path" {
  type        = string
  description = "Health check path exposed by Keycloak for ALB target group probes"
  default     = "/health/ready"
}

variable "external_dns_chart_version" {
  type        = string
  description = "Pinned external-dns Helm chart version"
  default     = "1.14.4"
}

variable "cert_manager_chart_version" {
  type        = string
  description = "Pinned cert-manager Helm chart version"
  default     = "1.14.4"
}
