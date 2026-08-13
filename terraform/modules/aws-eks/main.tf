# AWS EKS Module — Managed K8s with IRSA, node groups, autoscaling, addons

data "aws_region" "current" {}

# Cluster IAM role
resource "aws_iam_role" "cluster" {
  name = "${var.name}-eks-cluster"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# KMS for secret encryption
resource "aws_kms_key" "eks" {
  description             = "EKS secret encryption key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.tags
}

# CloudWatch logs
resource "aws_cloudwatch_log_group" "eks" {
  name              = "/aws/eks/${var.name}/cluster"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

# EKS Cluster
resource "aws_eks_cluster" "this" {
  name     = var.name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = concat(var.public_subnet_ids, var.private_subnet_ids)
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  encryption_config {
    provider { key_arn = aws_kms_key.eks.arn }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_cloudwatch_log_group.eks,
  ]

  tags = var.tags
}

# Node group IAM role
resource "aws_iam_role" "node_group" {
  name = "${var.name}-node-group"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_eks_worker" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_eks_cni" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_ecr_readonly" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# System node group (critical addons only)
resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-system"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids

  ami_type       = "AL2_x86_64"
  capacity_type  = "ON_DEMAND"
  instance_types = var.system_instance_types

  scaling_config {
    desired_size = var.system_desired_size
    max_size     = var.system_max_size
    min_size     = var.system_min_size
  }

  update_config { max_unavailable = 1 }

  labels = { role = "system", nodegroup = "system" }

  taint {
    key    = "CriticalAddonsOnly"
    value  = "true"
    effect = "NO_SCHEDULE"
  }

  tags = merge(var.tags, { Name = "${var.name}-system-node" })

  depends_on = [
    aws_iam_role_policy_attachment.node_eks_worker,
    aws_iam_role_policy_attachment.node_eks_cni,
    aws_iam_role_policy_attachment.node_ecr_readonly,
  ]
}

# Application node group
resource "aws_eks_node_group" "application" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-application"
  node_role_arn   = aws_iam_role.node_group.arn
  subnet_ids      = var.private_subnet_ids

  ami_type       = "AL2_x86_64"
  capacity_type  = "ON_DEMAND"
  instance_types = var.app_instance_types

  scaling_config {
    desired_size = var.app_desired_size
    max_size     = var.app_max_size
    min_size     = var.app_min_size
  }

  update_config { max_unavailable = 1 }

  labels = { role = "application", nodegroup = "application" }

  tags = merge(var.tags, { Name = "${var.name}-app-node" })

  depends_on = [
    aws_iam_role_policy_attachment.node_eks_worker,
    aws_iam_role_policy_attachment.node_eks_cni,
    aws_iam_role_policy_attachment.node_ecr_readonly,
  ]
}

# OIDC provider (needed for IRSA)
data "tls_certificate" "eks" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  tags            = var.tags
}