# Copyright 2023 Amazon.com, Inc. or its affiliates. All Rights Reserved.
# Permission is hereby granted, free of charge, to any person obtaining a copy of this
# software and associated documentation files (the "Software"), to deal in the Software
# without restriction, including without limitation the rights to use, copy, modify,
# merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

locals {
  region = data.aws_region.current.name
}

data "aws_region" "current" {}

output "db_hostname" {
  value = module.dev_database.db_hostname
}

output "cert_arn" {
  value = var.cert_arn
}

module "dev_cluster" {
  source            = "./modules/cluster"
  route53_zone_id   = var.route53_zone_id
  route53_zone_name = var.route53_zone_name
  cert_arn          = var.cert_arn
  environment       = var.environment
  cluster_version   = var.cluster_version
  region            = local.region
  alb_controller_chart_version = var.alb_controller_chart_version
  alb_controller_image_tag     = var.alb_controller_image_tag
  keycloak_username            = var.keycloak_username
  keycloak_password            = var.keycloak_password
  db_username                  = var.db_username
  db_password                  = var.db_password
  database_name                = var.database_name
  keycloak_namespace           = var.keycloak_namespace
  keycloak_admin_secret_name   = var.keycloak_admin_secret_name
  keycloak_db_secret_name      = var.keycloak_db_secret_name
}

module "dev_autoscaler" {
  source                             = "./modules/cluster-autoscaler"
  cluster_identity_oidc_issuer       = module.dev_cluster.cluster_identity_oidc_issuer
  cluster_identity_oidc_issuer_arn   = module.dev_cluster.cluster_identity_oidc_issuer_arn
  cluster_endpoint                   = module.dev_cluster.cluster_endpoint
  cluster_certificate_authority_data = module.dev_cluster.cluster_certificate_authority_data
}

module "dev_database" {
  source                       = "./modules/database"
  db_username                  = var.db_username
  db_password                  = var.db_password
  database_name                = var.database_name
  vpc_id                       = module.dev_cluster.vpc_id
  database_subnets             = module.dev_cluster.database_subnets
  database_subnets_cidr_blocks = module.dev_cluster.database_subnets_cidr_blocks
  cluster_sg_id                = module.dev_cluster.cluster_sg_id
}

data "aws_eks_cluster" "demo" {
  name = module.dev_cluster.cluster_name
}

data "aws_eks_cluster_auth" "demo" {
  name = module.dev_cluster.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.demo.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.demo.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.demo.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.demo.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.demo.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.demo.token
  }
}

locals {
  keycloak_values = templatefile("${path.module}/values/keycloak-demo.yaml", {
    keycloak_hostname          = var.keycloak_hostname
    keycloak_admin_secret_name = var.keycloak_admin_secret_name
    keycloak_db_secret_name    = var.keycloak_db_secret_name
    database_name              = var.database_name
    db_username                = var.db_username
    db_hostname                = module.dev_database.db_hostname
    cert_arn                   = var.cert_arn
    alb_log_bucket             = var.alb_log_bucket
    alb_log_prefix             = var.alb_log_prefix
    keycloak_image_tag         = var.keycloak_image_tag
    keycloak_namespace         = var.keycloak_namespace
  })
}

resource "helm_release" "keycloak" {
  name       = "keycloak"
  chart      = "keycloak"
  repository = "https://charts.bitnami.com/bitnami"
  version    = var.keycloak_chart_version
  namespace  = var.keycloak_namespace

  values = [local.keycloak_values]

  depends_on = [module.dev_cluster, module.dev_database]
}