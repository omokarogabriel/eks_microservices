resource "aws_iam_user" "readonly_user" {
  name = "${var.cluster_name}-readonly-user"
  path = "/eks/"

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-readonly-user"
    Type = "eks-readonly-user"
  })
}

resource "aws_iam_access_key" "readonly_user" {
  user = aws_iam_user.readonly_user.name
}

resource "aws_iam_user_policy" "readonly_eks_policy" {
  name = "${var.cluster_name}-readonly-eks-policy"
  user = aws_iam_user.readonly_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })
}

# Kubernetes RBAC resources removed to avoid provider connection issues
# These can be created manually after cluster deployment:
# kubectl apply -f - <<EOF
# apiVersion: rbac.authorization.k8s.io/v1
# kind: ClusterRole
# metadata:
#   name: eks-readonly
# rules:
# - apiGroups: [""]
#   resources: ["*"]
#   verbs: ["get", "list", "watch"]
# - apiGroups: ["apps", "extensions"]
#   resources: ["*"]
#   verbs: ["get", "list", "watch"]
# - apiGroups: ["batch"]
#   resources: ["*"]
#   verbs: ["get", "list", "watch"]
# ---
# apiVersion: rbac.authorization.k8s.io/v1
# kind: ClusterRoleBinding
# metadata:
#   name: eks-readonly-binding
# roleRef:
#   apiGroup: rbac.authorization.k8s.io
#   kind: ClusterRole
#   name: eks-readonly
# subjects:
# - kind: User
#   name: readonly-user
#   apiGroup: rbac.authorization.k8s.io
# EOF