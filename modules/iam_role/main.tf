###Create EKS cluster IAM role
resource "aws_iam_role" "eks_master_role" {
  name_prefix = "${var.cluster_name}-cluster-role-"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

# Attach the AmazonEKSClusterPolicy to the role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy_attach" {
  role       = aws_iam_role.eks_master_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}




###Create EKS worker node IAM role
resource "aws_iam_role" "eks_worker_role" {
  name_prefix        = "${var.cluster_name}-node-role-"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

### Attach the AmazonEKSWorkerNodePolicy to the role
resource "aws_iam_role_policy_attachment" "eks_worker_policy_attach" {
  role       = aws_iam_role.eks_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

### Attach the AmazonEC2ContainerRegistryReadOnly to the role
resource "aws_iam_role_policy_attachment" "eks_container_registry_ro_policy_attach" {
  role       = aws_iam_role.eks_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

### Attach the AmazonEKS_CNI_Policy to the role
resource "aws_iam_role_policy_attachment" "eks_cni_policy_attach" {
  role       = aws_iam_role.eks_worker_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}



# End of IAM Role for EKS Cluster and Worker Nodes


###Create EKS EBS CSI Driver IAM Role
resource "aws_iam_role" "eks_ebs_csi_driver_role" {
  count       = var.enable_ebs_csi_driver ? 1 : 0
  name_prefix = "${var.cluster_name}-ebs-csi-role-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(var.oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-ebs-csi-role"
    Type = "service-account-role"
  })
}

### Attach the AmazonEBSCSIDriverPolicy to the role
resource "aws_iam_role_policy_attachment" "eks_ebs_csi_driver_policy_attach" {
  count      = var.enable_ebs_csi_driver ? 1 : 0
  role       = aws_iam_role.eks_ebs_csi_driver_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}



# End of IAM Role for EKS EBS CSI Driver