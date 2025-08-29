############################################
# main.tf — IAM for EKS & common controllers
############################################

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# -------------------------------------------------
# 1) IAM role for the EKS control plane (cluster)
# -------------------------------------------------
data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
  tags               = var.tags
}

# Attach the standard AWS managed policies
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_iam_role_policy_attachment" "eks_vpc_ctrl" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_VPCResourceController"
}

# -------------------------------------------------
# 2) IAM role + instance profile for worker nodes
#    (works for EKS managed node groups or self-managed)
# -------------------------------------------------
data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_node" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json
  tags               = var.tags
}

# Standard AWS managed policies for nodes
resource "aws_iam_role_policy_attachment" "node_AmazonEKSWorkerNodePolicy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "node_AmazonEKS_CNI_Policy" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "node_AmazonEC2ContainerRegistryReadOnly" {
  role       = aws_iam_role.eks_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Instance profile (for self-managed nodes or if you prefer to pass explicitly)
resource "aws_iam_instance_profile" "eks_node" {
  name = "${var.cluster_name}-node-instance-profile"
  role = aws_iam_role.eks_node.name
  tags = var.tags
}

# -------------------------------------------------
# 3) IRSA roles for common controllers (optional)
#    Requires your EKS OIDC provider ARN and SA names
# -------------------------------------------------
# Reusable inline locals for provider map
locals {
  oidc_providers = {
    this = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = []
    }
  }
}

# AWS Load Balancer Controller
module "irsa_alb" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  count = var.enable_irsa_alb ? 1 : 0

  role_name_prefix                     = "${var.cluster_name}-alb"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    this = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = var.tags
}

# Cluster Autoscaler
module "irsa_cluster_autoscaler" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  count = var.enable_irsa_cluster_autoscaler ? 1 : 0

  role_name_prefix                 = "${var.cluster_name}-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true

  oidc_providers = {
    this = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }

  tags = var.tags
}

# ExternalDNS
module "irsa_external_dns" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  count = var.enable_irsa_external_dns ? 1 : 0

  role_name_prefix            = "${var.cluster_name}-external-dns"
  attach_external_dns_policy  = true

  oidc_providers = {
    this = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }

  tags = var.tags
}

# Fluent Bit (to CloudWatch)
module "irsa_fluent_bit" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  count = var.enable_irsa_fluent_bit ? 1 : 0

  role_name_prefix                = "${var.cluster_name}-fluent-bit"
  attach_cloudwatch_logs_policy   = true

  oidc_providers = {
    this = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["amazon-cloudwatch:fluent-bit"]
    }
  }

  tags = var.tags
}

# EBS CSI Driver (if using the EKS add-on with IRSA)
module "irsa_ebs_csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  count = var.enable_irsa_ebs_csi ? 1 : 0

  role_name_prefix               = "${var.cluster_name}-ebs-csi"
  attach_ebs_csi_policy         = true

  oidc_providers = {
    this = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = var.tags
}

# --------------------------------
# Outputs
# --------------------------------
output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}
output "eks_node_role_arn" {
  value = aws_iam_role.eks_node.arn
}
output "eks_node_instance_profile_name" {
  value = aws_iam_instance_profile.eks_node.name
}

output "irsa_role_arns" {
  value = compact([
    try(module.irsa_alb[0].iam_role_arn, null),
    try(module.irsa_cluster_autoscaler[0].iam_role_arn, null),
    try(module.irsa_external_dns[0].iam_role_arn, null),
    try(module.irsa_fluent_bit[0].iam_role_arn, null),
    try(module.irsa_ebs_csi[0].iam_role_arn, null)
  ])
}
