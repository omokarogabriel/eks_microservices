output "cluster_security_group_id" {
  description = "Security group ID for EKS cluster"
  value       = aws_security_group.eks_cluster_sg.id
}

output "cluster_security_group_arn" {
  description = "Security group ARN for EKS cluster"
  value       = aws_security_group.eks_cluster_sg.arn
}

output "node_security_group_id" {
  description = "Security group ID for EKS nodes"
  value       = aws_security_group.eks_node_sg.id
}

output "node_security_group_arn" {
  description = "Security group ARN for EKS nodes"
  value       = aws_security_group.eks_node_sg.arn
}

output "pod_security_group_id" {
  description = "Security group ID for EKS pods"
  value       = aws_security_group.eks_pod_sg.id
}

output "pod_security_group_arn" {
  description = "Security group ARN for EKS pods"
  value       = aws_security_group.eks_pod_sg.arn
}

output "alb_security_group_id" {
  description = "Security group ID for ALB"
  value       = var.enable_alb_security_group ? aws_security_group.alb_sg.id : null
}

output "alb_security_group_arn" {
  description = "Security group ARN for ALB"
  value       = var.enable_alb_security_group ? aws_security_group.alb_sg.arn : null
}

output "database_security_group_id" {
  description = "Security group ID for databases"
  value       = aws_security_group.database_sg.id
}

output "redis_security_group_id" {
  description = "Security group ID for Redis"
  value       = aws_security_group.redis_sg.id
}

output "all_security_group_ids" {
  description = "Map of all security group IDs"
  value = {
    cluster = aws_security_group.eks_cluster_sg.id
    node    = aws_security_group.eks_node_sg.id
    pod     = aws_security_group.eks_pod_sg.id
    alb     = var.enable_alb_security_group ? aws_security_group.alb_sg.id : null
  }
}

output "security_group_rules" {
  description = "Security group rules summary"
  value = {
    cluster_rules = {
      ingress = [aws_security_group_rule.cluster_ingress_nodes.id]
    }
    node_rules = {
      ingress = [
        aws_security_group_rule.node_ingress_cluster.id,
        aws_security_group_rule.node_ingress_self.id,
        aws_security_group_rule.node_ingress_self_udp.id
      ]
      egress = [aws_security_group_rule.node_egress_internet.id]
    }
    pod_rules = {
      ingress = [aws_security_group_rule.pod_ingress_cluster.id]
      egress  = [aws_security_group_rule.pod_egress_internet.id]
    }
    alb_rules = var.enable_alb_security_group ? {
      ingress = [
        aws_security_group_rule.alb_ingress_http.id,
        aws_security_group_rule.alb_ingress_https.id
      ]
      egress = [aws_security_group_rule.alb_egress_all.id]
    } : null
  }
}