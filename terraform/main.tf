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

terraform {
  required_version = "~> 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

output "db_hostname" {
  value = module.dev_database.db_hostname
}

output "cert_arn" {
  value = var.cert_arn
}

data "aws_availability_zones" "available" {}

resource "aws_kms_key" "flowlog_key" {
  description             = "KMS key for ${var.cluster_name} VPC Flow logs"
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "flowlog_alias" {
  name          = "alias/vpcflowlog-key"
  target_key_id = aws_kms_key.flowlog_key.id
}

resource "aws_iam_role" "cw_role" {
  name = "cloudwatch-role-${var.cluster_name}"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "vpc-flow-logs.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cw_role_attachment" {
  role       = aws_iam_role.cw_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_iam_policy" "ec2_policy" {
  name   = "${var.cluster_name}-ec2-policy"
  policy = file("modules/iam/worker-policy.json")
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name                 = var.cluster_name
  cidr                 = "172.16.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
  public_subnets       = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
  database_subnets     = ["172.16.10.0/24", "172.16.11.0/24", "172.16.12.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  map_public_ip_on_launch = false
  create_flow_log_cloudwatch_log_group          = true
  flow_log_cloudwatch_iam_role_arn              = aws_iam_role.cw_role.arn
  flow_log_cloudwatch_log_group_retention_in_days = 30
  flow_log_destination_type                     = "cloud-watch-logs"
  flow_log_file_format                          = "plain-text"
  flow_log_traffic_type                         = "ALL"

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}"          = "shared"
    "kubernetes.io/role/elb"                             = "1"
    "k8s.io/cluster-autoscaler/${var.cluster_name}"      = "owned"
    "kubernetes.io/role/internal-elb"                    = "true"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}"          = "shared"
    "kubernetes.io/role/internal-elb"                    = "1"
    "k8s.io/cluster-autoscaler/${var.cluster_name}"      = "owned"
    "kubernetes.io/role/internal-elb"                    = "true"
  }

  database_subnet_tags = {
    "kubernetes.io/cluster/${var.cluster_name}"          = "shared"
    "kubernetes.io/role/internal-elb"                    = "1"
    "k8s.io/cluster-autoscaler/${var.cluster_name}"      = "owned"
    "kubernetes.io/role/internal-elb"                    = "true"
  }

  tags = {
    environment = var.environment
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  enable_irsa     = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = [var.node_instance_type]
      capacity_type  = "ON_DEMAND"
      iam_role_additional_policies = {
        worker = aws_iam_policy.ec2_policy.arn
      }
    }
  }

  tags = {
    environment = var.environment
  }
}

data "aws_eks_cluster_auth" "demo" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.demo.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.demo.token
  }
}

data "aws_iam_policy_document" "alb_controller_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
  }
}

resource "aws_iam_policy" "alb_controller_policy" {
  name        = "${var.cluster_name}-alb-controller-policy"
  description = "AWS Load Balancer Controller IAM policy for Helm-managed service account"
  policy      = file("modules/iam/AWSLoadBalancerControllerIAMPolicy.json")
}

resource "aws_iam_role" "alb_controller" {
  name               = "${var.cluster_name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume_role.json
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller_policy.arn
}

resource "aws_iam_policy" "alb_controller_logs" {
  name        = "${var.cluster_name}-alb-controller-logs"
  description = "Allow ALB controller to write to CloudWatch logs"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "alb_controller_logs" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller_logs.arn
}

data "aws_iam_policy_document" "external_dns_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.cluster_oidc_issuer_url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:external-dns"]
    }

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
  }
}

resource "aws_iam_policy" "dnsupdate_policy" {
  name        = "dnsupdate-policy-${var.cluster_name}"
  description = "DNS update policy for Route53 Resource Record Sets and Hosted Zones"

  policy = file("modules/iam/dns-update-policy.json")
}

resource "aws_iam_role" "external_dns" {
  name               = "${var.cluster_name}-external-dns"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume_role.json
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.dnsupdate_policy.arn
}

resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
    }
  }

  depends_on = [aws_iam_role_policy_attachment.alb_controller]
}

resource "kubernetes_service_account" "external_dns" {
  metadata {
    name      = "external-dns"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns.arn
    }
  }

  depends_on = [aws_iam_role_policy_attachment.external_dns]
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "helm_release" "ingress" {
  name       = "aws-load-balancer-controller"
  chart      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  version    = var.alb_controller_chart_version
  namespace  = "kube-system"

  set {
    name  = "autoDiscoverAwsRegion"
    value = "true"
  }
  set {
    name  = "autoDiscoverAwsVpcID"
    value = "true"
  }
  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "image.tag"
    value = var.alb_controller_image_tag
  }
  set {
    name  = "enableServiceMutator"
    value = true
  }
  set {
    name  = "serviceAccount.create"
    value = false
  }
  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.alb_controller.metadata[0].name
  }

  depends_on = [kubernetes_service_account.alb_controller]
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  chart      = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  version    = var.external_dns_chart_version
  namespace  = "kube-system"

  set {
    name  = "provider"
    value = "aws"
  }
  set {
    name  = "policy"
    value = "upsert-only"
  }
  set {
    name  = "aws.region"
    value = var.aws_region
  }
  set {
    name  = "domainFilters[0]"
    value = var.route53_zone_name
  }
  set {
    name  = "txtOwnerId"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = false
  }
  set {
    name  = "serviceAccount.name"
    value = kubernetes_service_account.external_dns.metadata[0].name
  }

  depends_on = [kubernetes_service_account.external_dns]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  chart      = "cert-manager"
  repository = "https://charts.jetstack.io"
  version    = var.cert_manager_chart_version
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name

  set {
    name  = "installCRDs"
    value = true
  }

  depends_on = [kubernetes_namespace.cert_manager]
}

resource "aws_security_group" "lb_security_group" {
  name        = "${var.cluster_name}-lb-sg"
  vpc_id      = module.vpc.vpc_id
  description = "Security group for Ingress ALB"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["52.94.133.131/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "dev_database" {
  source                       = "./modules/database"
  db_username                  = var.db_username
  db_password                  = var.db_password
  database_name                = var.database_name
  vpc_id                       = module.vpc.vpc_id
  database_subnets             = module.vpc.database_subnets
  cluster_sg_id                = module.eks.node_security_group_id
  region                       = var.aws_region
}

resource "kubernetes_namespace" "keycloak" {
  metadata {
    name = var.keycloak_namespace
  }

  depends_on = [module.eks]
}

resource "kubernetes_secret" "keycloak_admin" {
  metadata {
    name      = var.keycloak_admin_secret_name
    namespace = kubernetes_namespace.keycloak.metadata[0].name
  }

  type = "Opaque"

  string_data = {
    username = var.keycloak_username
    password = var.keycloak_password
  }

  depends_on = [kubernetes_namespace.keycloak]
}

resource "kubernetes_secret" "keycloak_database" {
  metadata {
    name      = var.keycloak_db_secret_name
    namespace = kubernetes_namespace.keycloak.metadata[0].name
  }

  type = "Opaque"

  string_data = {
    username = var.db_username
    password = var.db_password
    database = var.database_name
  }

  depends_on = [kubernetes_namespace.keycloak]
}

locals {
  keycloak_values = templatefile("${path.module}/values/keycloak-demo.yaml", {
    keycloak_hostname            = var.keycloak_hostname
    keycloak_admin_secret_name   = var.keycloak_admin_secret_name
    keycloak_db_secret_name      = var.keycloak_db_secret_name
    database_name                = var.database_name
    db_username                  = var.db_username
    db_hostname                  = module.dev_database.db_hostname
    cert_arn                     = var.cert_arn
    alb_log_bucket               = var.alb_log_bucket
    alb_log_prefix               = var.alb_log_prefix
    alb_ingress_group_name       = var.alb_ingress_group_name
    alb_ingress_healthcheck_path = var.alb_ingress_healthcheck_path
    keycloak_image_tag           = var.keycloak_image_tag
    keycloak_namespace           = var.keycloak_namespace
  })
}

resource "helm_release" "keycloak" {
  name       = "keycloak"
  chart      = "keycloak"
  repository = "https://charts.bitnami.com/bitnami"
  version    = var.keycloak_chart_version
  namespace  = var.keycloak_namespace

  values = [local.keycloak_values]

  depends_on = [module.eks, module.dev_database]
}
