variable "route53_zone_id" {
  type        = string
  description = "Route53 Zone ID"
}

variable "route53_zone_name" {
  type        = string
  description = "Route53 Zone Name"
}

variable "region" {
  type        = string
  description = "Region Name"
}

variable "cert_arn" {
  type        = string
  description = "Route53 Hosted Zone ID AWS Certificate Manager ARN"
}

variable "environment" {
  type        = string
  description = "Environment workspace"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name"
  default = "keycloak-demo"
}

variable "cluster_version" {
  type        = string
  description = "EKS cluster version"
}

variable "instance_type" {
  type        = string
  description = "EC2 Instance Type"
  default = "t3.large"
}

variable "alb_controller_chart_version" {
  type        = string
  description = "Pinned AWS Load Balancer Controller Helm chart version"
}

variable "alb_controller_image_tag" {
  type        = string
  description = "AWS Load Balancer Controller image tag"
}

variable "external_dns_chart_version" {
  type        = string
  description = "Pinned external-dns Helm chart version"
}

variable "cert_manager_chart_version" {
  type        = string
  description = "Pinned cert-manager Helm chart version"
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

variable "kms_alias" {
  default     = "vpcflowlog_key"
  description = "KMS Key Alias for VPC flow log key"
  type        = string
}

variable "keycloak_username" {
  type        = string
  description = "Keycloak admin username"
}

variable "keycloak_password" {
  type        = string
  description = "Keycloak admin password"
  sensitive   = true
}

variable "db_username" {
  type        = string
  description = "Database username for Keycloak"
}

variable "db_password" {
  type        = string
  description = "Database password for Keycloak"
  sensitive   = true
}

variable "database_name" {
  type        = string
  description = "Database name for Keycloak"
}

variable "keycloak_namespace" {
  type        = string
  description = "Namespace for Keycloak resources"
}