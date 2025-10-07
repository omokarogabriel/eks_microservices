# EKS Control Plane Security Group
resource "aws_security_group" "eks_cluster_sg" {
  name_prefix = "${var.cluster_name}-cluster-"
  description = "EKS cluster control plane security group"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name                                        = "${var.cluster_name}-cluster-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

# Allow nodes to communicate with cluster API
resource "aws_security_group_rule" "cluster_ingress_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_cluster_sg.id
  source_security_group_id = aws_security_group.eks_node_sg.id
  description              = "Allow nodes to communicate with cluster API"
}

# EKS Node Security Group
resource "aws_security_group" "eks_node_sg" {
  name_prefix = "${var.cluster_name}-node-"
  description = "EKS node group security group"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name                                        = "${var.cluster_name}-node-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

# Allow cluster to communicate with nodes
resource "aws_security_group_rule" "node_ingress_cluster" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.eks_node_sg.id
  source_security_group_id = aws_security_group.eks_cluster_sg.id
  description              = "Allow cluster control plane to communicate with nodes"
}

# Allow nodes to communicate with each other
resource "aws_security_group_rule" "node_ingress_self" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_node_sg.id
  self              = true
  description       = "Allow nodes to communicate with each other"
}

# Allow nodes to communicate with each other on UDP
resource "aws_security_group_rule" "node_ingress_self_udp" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "udp"
  security_group_id = aws_security_group.eks_node_sg.id
  self              = true
  description       = "Allow nodes to communicate with each other on UDP"
}

# Allow outbound internet access for nodes
resource "aws_security_group_rule" "node_egress_internet" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.eks_node_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow nodes outbound internet access"
}

# Additional Security Group for Pods (CNI)
resource "aws_security_group" "eks_pod_sg" {
  name_prefix = "${var.cluster_name}-pod-"
  description = "EKS pod security group for additional ENI"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name                                        = "${var.cluster_name}-pod-sg"
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

# Allow pods to communicate within cluster
resource "aws_security_group_rule" "pod_ingress_cluster" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  security_group_id = aws_security_group.eks_pod_sg.id
  cidr_blocks       = [var.vpc_cidr]
  description       = "Allow pod communication within VPC"
}

# Allow outbound internet access for pods
resource "aws_security_group_rule" "pod_egress_internet" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.eks_pod_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow pods outbound internet access"
}

# ALB Controller Security Group
resource "aws_security_group" "alb_sg" {
  name_prefix = "${var.cluster_name}-alb-"
  description = "Security group for ALB ingress"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-alb-sg"
  })
}

# ALB HTTP ingress rule
resource "aws_security_group_rule" "alb_ingress_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTP access from internet"
}

# ALB HTTPS ingress rule
resource "aws_security_group_rule" "alb_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS access from internet"
}

# ALB egress rule
resource "aws_security_group_rule" "alb_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.alb_sg.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "All outbound traffic"
}

# Database Security Group
resource "aws_security_group" "database_sg" {
  name_prefix = "${var.cluster_name}-database-"
  description = "Security group for RDS databases"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-database-sg"
  })
}

# Database ingress from EKS nodes
resource "aws_security_group_rule" "database_ingress_nodes" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.database_sg.id
  source_security_group_id = aws_security_group.eks_node_sg.id
  description              = "Database access from EKS nodes"
}

# Redis Security Group
resource "aws_security_group" "redis_sg" {
  name_prefix = "${var.cluster_name}-redis-"
  description = "Security group for Redis ElastiCache"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-redis-sg"
  })
}

# Redis ingress from EKS nodes
resource "aws_security_group_rule" "redis_ingress_nodes" {
  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  security_group_id        = aws_security_group.redis_sg.id
  source_security_group_id = aws_security_group.eks_node_sg.id
  description              = "Redis access from EKS nodes"
}