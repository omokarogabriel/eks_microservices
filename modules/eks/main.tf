###CloudWatch Log Group for EKS cluster
resource "aws_cloudwatch_log_group" "eks" {
  count             = var.enable_cluster_logging ? 1 : 0
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.cluster_log_retention_days
  kms_key_id        = var.kms_key_arn

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-eks-logs"
    Type = "cloudwatch-log-group"
  })
}

###create aws_eks_cluster resource
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  dynamic "encryption_config" {
    for_each = var.kms_key_arn != null ? [1] : []
    content {
      provider {
        key_arn = var.kms_key_arn
      }
      resources = ["secrets"]
    }
  }

  enabled_cluster_log_types = var.enable_cluster_logging ? var.cluster_log_types : []

  depends_on = [aws_cloudwatch_log_group.eks]



  tags = merge(var.common_tags, {
    Name = var.cluster_name
  })
}

###EKS Addons
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "vpc-cni"

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-vpc-cni"
  })
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "coredns"

  depends_on = [aws_eks_node_group.this]

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-coredns"
  })
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.this.name
  addon_name   = "kube-proxy"

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-kube-proxy"
  })
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = var.ebs_csi_role_arn

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-ebs-csi-driver"
  })
}


###create aws_eks_node_group resource
resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-node-group"
  node_role_arn   = var.node_role_arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = var.instance_types
  disk_size       = var.disk_size
  capacity_type   = var.capacity_type
  ami_type        = var.ami_type

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-node-group"
  })

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }
  update_config {
    max_unavailable = 1
  }
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

}