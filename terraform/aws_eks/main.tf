# Module from Hashicorp

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.29"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }
}

provider "aws" {
  region = var.region
}


# Module for EKS

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  enable_irsa = true

  # Managed node group (simple example)
  managed_node_groups = {
    default = {
      desired_size = 2
      min_size     = 1
      max_size     = 2
      instance_types = ["t3.large"]
      capacity_type  = "SPOT"
    }
  }

  tags = {
    Project     = "platform"
    Environment = var.environment
  }
}

# -----------------------------------------
# Wire up Kubernetes & Helm providers to EKS
# -----------------------------------------
data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

# ---------------------------
# Official EKS Add-ons (AWS)
# (No version specified = latest compatible)
# ---------------------------
# Core networking & control-plane agents
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

# Storage drivers
resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

# (If available in your region/account)
# resource "aws_eks_addon" "efs_csi" {
#   cluster_name                = module.eks.cluster_name
#   addon_name                  = "aws-efs-csi-driver"
#   resolve_conflicts_on_create = "OVERWRITE"
#   resolve_conflicts_on_update = "OVERWRITE"
# }

# Observability & identity helpers
resource "aws_eks_addon" "pod_identity" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

# OpenTelemetry (ADOT)
resource "aws_eks_addon" "adot" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "adot"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

# CloudWatch Observability (if supported in your region)
resource "aws_eks_addon" "cloudwatch_obs" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "amazon-cloudwatch-observability"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  # Some accounts/regions may not support this yet; toggle via var.enable_cloudwatch_observability
  count = var.enable_cloudwatch_observability ? 1 : 0
}

# ----------------------------------------------------
# Popular ecosystem "plugins" (Helm charts) with IRSA
# ----------------------------------------------------

# AWS Load Balancer Controller
module "alb_irsa" {
  source              = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version             = "~> 5.44"
  role_name_prefix    = "${var.cluster_name}-alb"
  attach_load_balancer_controller_policy = true
  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = var.alb_chart_version

  create_namespace = false

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = false
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "region"
    value = var.region
  }

  depends_on = [module.alb_irsa]
}

# Metrics Server (HPA source of metrics)
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = var.metrics_server_chart_version

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }
}

# Cluster Autoscaler (uses IRSA with AWS auth)
module "ca_irsa" {
  source           = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version          = "~> 5.44"
  role_name_prefix = "${var.cluster_name}-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true

  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }
}

resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = var.cluster_autoscaler_chart_version

  set {
    name  = "autoDiscovery.clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.region
  }

  set {
    name  = "rbac.serviceAccount.create"
    value = false
  }

  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  depends_on = [module.ca_irsa]
}

# ExternalDNS (optional; set var.enable_external_dns = true)
module "external_dns_irsa" {
  source           = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version          = "~> 5.44"
  role_name_prefix = "${var.cluster_name}-external-dns"
  attach_external_dns_policy = true

  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }

  count = var.enable_external_dns ? 1 : 0
}

resource "helm_release" "external_dns" {
  count      = var.enable_external_dns ? 1 : 0
  name       = "external-dns"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  namespace  = "kube-system"
  version    = var.external_dns_chart_version

  set {
    name  = "provider"
    value = "aws"
  }

  set {
    name  = "policy"
    value = "upsert-only"
  }

  set {
    name  = "serviceAccount.create"
    value = false
  }

  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }

  depends_on = [module.external_dns_irsa]
}

# Fluent Bit for CloudWatch logs (optional)
module "fluentbit_irsa" {
  source           = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version          = "~> 5.44"
  role_name_prefix = "${var.cluster_name}-fluent-bit"
  attach_cloudwatch_logs_policy = true

  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["amazon-cloudwatch:fluent-bit"]
    }
  }

  count = var.enable_fluentbit ? 1 : 0
}

resource "helm_release" "aws_for_fluent_bit" {
  count      = var.enable_fluentbit ? 1 : 0
  name       = "aws-for-fluent-bit"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"
  namespace  = "amazon-cloudwatch"
  version    = var.fluentbit_chart_version

  create_namespace = true

  set {
    name  = "serviceAccount.create"
    value = false
  }

  set {
    name  = "serviceAccount.name"
    value = "fluent-bit"
  }

  depends_on = [module.fluentbit_irsa]
}


