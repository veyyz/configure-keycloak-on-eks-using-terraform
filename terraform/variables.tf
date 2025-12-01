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
  default     = "1.8.0"
}

variable "alb_controller_image_tag" {
  type        = string
  description = "AWS Load Balancer Controller image tag"
  default     = "v1.8.2"
}

variable "keycloak_chart_version" {
  type        = string
  description = "Pinned Keycloak Helm chart version for the demo"
  default     = "24.0.2"
}

variable "keycloak_image_tag" {
  type        = string
  description = "Keycloak container image tag to deploy (avoid 'latest' for deterministic demos)"
  default     = "24.0.5"
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
