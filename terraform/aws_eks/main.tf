############################################
# modules/aws_eks/main.tf
############################################

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
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

provider "aws" {
  region = var.region
}

# -----------------------------------------
# EKS (terraform-aws-modules/eks v20+)
# -----------------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnet_ids

  enable_irsa = true

  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.eks_public_endpoint_cidrs

  # Access Entries (cluster-admin for your principal)
  access_entries = {
    admin = {
      principal_arn = var.admin_principal_arn
      policy_associations = [
        {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      ]
    }
  }

  eks_managed_node_groups = {
    default = {
      desired_size   = 2
      min_size       = 1
      max_size       = 2
      instance_types = ["t3.medium"]
      capacity_type  = "SPOT"
    }
  }

  tags = {
    Project     = "platform"
    Environment = var.environment
  }
}

# -----------------------------------------
# Wait for control plane ACTIVE
# -----------------------------------------
resource "null_resource" "wait_for_api" {
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command = <<-EOT
      $ErrorActionPreference = "Stop"
      aws eks wait cluster-active --name "${module.eks.cluster_name}" --region "${var.region}"
      Write-Host "EKS cluster is ACTIVE."
    EOT
  }

  depends_on = [module.eks]

  triggers = {
    cluster = module.eks.cluster_name
    region  = var.region
  }
}

# -----------------------------------------
# Wait for nodegroups ACTIVE (discover dynamically)
# -----------------------------------------
resource "null_resource" "wait_for_nodegroups" {
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command = <<-EOT
      $ErrorActionPreference = "Stop"
      $cluster = "${module.eks.cluster_name}"
      $region  = "${var.region}"

      $ngs = (aws eks list-nodegroups --cluster-name $cluster --region $region --query "nodegroups" | ConvertFrom-Json)
      if (-not $ngs -or $ngs.Count -eq 0) {
        Write-Host "No nodegroups found (Fargate-only or still creating)."
        exit 0
      }
      foreach ($ng in $ngs) {
        Write-Host "Waiting for nodegroup '$ng' to be ACTIVE..."
        aws eks wait nodegroup-active --cluster-name $cluster --nodegroup-name $ng --region $region
      }
      Write-Host "All nodegroups ACTIVE."
    EOT
  }

  depends_on = [
    module.eks,
    null_resource.wait_for_api
  ]

  triggers = {
    cluster = module.eks.cluster_name
    region  = var.region
  }
}

# -----------------------------------------
# Get cluster connection data (after API is up)
# -----------------------------------------
data "aws_eks_cluster" "this" {
  name       = module.eks.cluster_name
  depends_on = [null_resource.wait_for_api]
}

# -----------------------------------------
# Providers with EXEC auth + explicit env (map form)
# -----------------------------------------
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name", module.eks.cluster_name,
      "--region",       var.region
    ]
    env = {
      AWS_REGION         = var.region
      AWS_DEFAULT_REGION = var.region
      AWS_PROFILE        = coalesce(var.aws_profile, "")
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region",       var.region
      ]
      env = {
        AWS_REGION         = var.region
        AWS_DEFAULT_REGION = var.region
        AWS_PROFILE        = coalesce(var.aws_profile, "")
      }
    }
  }

  repository_config_path = "${path.root}/.helm/repositories.yaml"
  repository_cache       = "${path.root}/.helm/cache"
}

# -----------------------------------------
# Helm repo init (Windows-safe) + cache in repo
# -----------------------------------------
resource "null_resource" "helm_repos" {
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command = <<-EOT
      $ErrorActionPreference = "Stop"
      $root = "${path.root}"
      $helmDir  = Join-Path $root ".helm"
      $repoFile = Join-Path $helmDir "repositories.yaml"
      $cacheDir = Join-Path $helmDir "cache"

      New-Item -ItemType Directory -Force -Path $helmDir  | Out-Null
      New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null

      $env:HELM_REPOSITORY_CONFIG = $repoFile
      $env:HELM_REPOSITORY_CACHE  = $cacheDir

      helm repo add jetstack       https://charts.jetstack.io                        | Out-Null
      helm repo add eks            https://aws.github.io/eks-charts                  | Out-Null
      helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ | Out-Null
      helm repo add autoscaler     https://kubernetes.github.io/autoscaler           | Out-Null
      helm repo add external-dns   https://kubernetes-sigs.github.io/external-dns    | Out-Null

      helm repo update | Out-Null
      Write-Host "Helm repos added and updated (local cache ready)."
    EOT
  }

  depends_on = [null_resource.wait_for_nodegroups]

  triggers = {
    repos = join(",", [
      "jetstack",
      "eks",
      "metrics-server",
      "autoscaler",
      "external-dns"
    ])
  }
}

# -----------------------------------------
# Official EKS Add-ons
# -----------------------------------------
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on = [null_resource.wait_for_nodegroups]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "kube-proxy"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on = [null_resource.wait_for_nodegroups]
}

resource "aws_eks_addon" "coredns" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on = [null_resource.wait_for_nodegroups]
}

resource "aws_eks_addon" "pod_identity" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on = [null_resource.wait_for_nodegroups]
}

# ---------------------------
# cert-manager
# ---------------------------
resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  version          = "v1.14.4"
  create_namespace = true
  wait             = true
  atomic           = true
  timeout          = 900

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [
    null_resource.helm_repos,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.coredns,
    aws_eks_addon.kube_proxy
  ]
}

# ---------------------------
# ADOT (optional)
# ---------------------------
resource "aws_eks_addon" "adot" {
  count                       = var.enable_adot ? 1 : 0
  cluster_name                = module.eks.cluster_name
  addon_name                  = "adot"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [helm_release.cert_manager]
}

# ---------------------------
# EBS CSI — Pod Identity
# ---------------------------
data "aws_iam_policy_document" "ebs_csi_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ebs_csi" {
  name               = "${var.cluster_name}-ebs-csi"
  assume_role_policy = data.aws_iam_policy_document.ebs_csi_trust.json
  tags               = { Component = "ebs-csi" }
}

resource "aws_iam_role_policy_attachment" "ebs_csi" {
  role       = aws_iam_role.ebs_csi.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_pod_identity_association" "ebs_csi" {
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "ebs-csi-controller-sa"
  role_arn        = aws_iam_role.ebs_csi.arn
  depends_on      = [aws_eks_addon.pod_identity]
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  depends_on                  = [aws_eks_pod_identity_association.ebs_csi]
}

# ---------------------------
# IRSA roles (pre-existing)
# ---------------------------
module "alb_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name_prefix                       = "${var.cluster_name}-alb"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

module "ca_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name_prefix                 = "${var.cluster_name}-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [module.eks.cluster_name]

  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:cluster-autoscaler"]
    }
  }
}

# ---------------------------
# PRE-CREATE ServiceAccounts with IRSA annotations
# ---------------------------
resource "kubernetes_service_account" "alb_sa" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.alb_irsa.iam_role_arn
    }
  }
  automount_service_account_token = true

  depends_on = [
    null_resource.wait_for_nodegroups
  ]
}

resource "kubernetes_service_account" "ca_sa" {
  metadata {
    name      = "cluster-autoscaler"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.ca_irsa.iam_role_arn
    }
    labels = {
      "k8s-addon" = "cluster-autoscaler.addons.k8s.io"
    }
  }
  automount_service_account_token = true

  depends_on = [
    null_resource.wait_for_nodegroups
  ]
}

# ---------------------------
# AWS Load Balancer Controller (Helm)
# ---------------------------
resource "helm_release" "aws_load_balancer_controller" {
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  namespace        = "kube-system"
  version          = var.alb_chart_version
  create_namespace = false
  wait             = true
  atomic           = true
  timeout          = 900

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "region"
    value = var.region
  }

  depends_on = [
    null_resource.helm_repos,
    kubernetes_service_account.alb_sa,
    module.alb_irsa,
    aws_eks_addon.vpc_cni,
    aws_eks_addon.coredns,
    aws_eks_addon.kube_proxy,
    helm_release.cert_manager
  ]
}

# ---------------------------
# Metrics Server
# ---------------------------
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"
  version    = var.metrics_server_chart_version
  wait       = true
  atomic     = true
  timeout    = 600

  set {
    name  = "args[0]"
    value = "--kubelet-insecure-tls"
  }

  depends_on = [
    null_resource.helm_repos,
    aws_eks_addon.coredns
  ]
}

# ---------------------------
# Cluster Autoscaler (Helm)
# ---------------------------
resource "helm_release" "cluster_autoscaler" {
  name             = "cluster-autoscaler"
  repository       = "https://kubernetes.github.io/autoscaler"
  chart            = "cluster-autoscaler"
  namespace        = "kube-system"
  version          = var.cluster_autoscaler_chart_version
  wait             = true
  atomic           = true
  timeout          = 900

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
    value = "false"
  }
  set {
    name  = "rbac.serviceAccount.name"
    value = "cluster-autoscaler"
  }

  depends_on = [
    null_resource.helm_repos,
    kubernetes_service_account.ca_sa,
    module.ca_irsa
  ]
}

# ---------------------------
# ExternalDNS (optional)
# ---------------------------
module "external_dns_irsa" {
  count   = var.enable_external_dns ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name_prefix           = "${var.cluster_name}-external-dns"
  attach_external_dns_policy = true

  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:external-dns"]
    }
  }
}

resource "helm_release" "external_dns" {
  count            = var.enable_external_dns ? 1 : 0
  name             = "external-dns"
  repository       = "https://kubernetes-sigs.github.io/external-dns"
  chart            = "external-dns"
  namespace        = "kube-system"
  version          = var.external_dns_chart_version
  wait             = true
  atomic           = true
  timeout          = 600

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
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = "external-dns"
  }

  depends_on = [
    null_resource.helm_repos,
    module.external_dns_irsa
  ]
}

# ---------------------------
# Fluent Bit (optional)
# ---------------------------
module "fluentbit_irsa" {
  count   = var.enable_fluentbit ? 1 : 0
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name_prefix = "${var.cluster_name}-fluent-bit"

  oidc_providers = {
    this = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["amazon-cloudwatch:fluent-bit"]
    }
  }

  role_policy_arns = {
    CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  }
}

resource "helm_release" "aws_for_fluent_bit" {
  count            = var.enable_fluentbit ? 1 : 0
  name             = "aws-for-fluent-bit"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-for-fluent-bit"
  namespace        = "amazon-cloudwatch"
  version          = var.fluentbit_chart_version
  create_namespace = true
  wait             = true
  atomic           = true
  timeout          = 600

  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = "fluent-bit"
  }

  depends_on = [
    null_resource.helm_repos,
    module.fluentbit_irsa
  ]
}
