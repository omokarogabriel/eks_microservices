output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.this.id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "EKS cluster Kubernetes version"
  value       = aws_eks_cluster.this.version
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

output "node_group_arn" {
  description = "EKS node group ARN"
  value       = aws_eks_node_group.this.arn
}

output "node_group_status" {
  description = "EKS node group status"
  value       = aws_eks_node_group.this.status
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_platform_version" {
  description = "Platform version for the EKS cluster"
  value       = aws_eks_cluster.this.platform_version
}

output "node_group_capacity_type" {
  description = "Type of capacity associated with the EKS Node Group"
  value       = aws_eks_node_group.this.capacity_type
}

output "node_group_instance_types" {
  description = "Set of instance types associated with the EKS Node Group"
  value       = aws_eks_node_group.this.instance_types
}

output "node_group_ami_type" {
  description = "Type of Amazon Machine Image (AMI) associated with the EKS Node Group"
  value       = aws_eks_node_group.this.ami_type
}

output "node_group_disk_size" {
  description = "Disk size in GiB for worker nodes"
  value       = aws_eks_node_group.this.disk_size
}

output "node_group_scaling_config" {
  description = "Configuration block with scaling settings"
  value       = aws_eks_node_group.this.scaling_config
}

output "cluster_primary_security_group_id" {
  description = "The cluster primary security group ID created by EKS"
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "cluster_vpc_config" {
  description = "Configuration block for the VPC associated with your cluster"
  value       = aws_eks_cluster.this.vpc_config
  sensitive   = false
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for EKS cluster"
  value       = var.enable_cluster_logging ? aws_cloudwatch_log_group.eks[0].name : null
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for EKS cluster"
  value       = var.enable_cluster_logging ? aws_cloudwatch_log_group.eks[0].arn : null
}

output "eks_addons" {
  description = "Map of EKS addons"
  value = {
    vpc_cni        = aws_eks_addon.vpc_cni.addon_name
    coredns        = aws_eks_addon.coredns.addon_name
    kube_proxy     = aws_eks_addon.kube_proxy.addon_name
    ebs_csi_driver = length(aws_eks_addon.ebs_csi_driver) > 0 ? aws_eks_addon.ebs_csi_driver[0].addon_name : null
  }
}

output "node_group_resources" {
  description = "EKS node group resource information"
  value = {
    capacity_type  = aws_eks_node_group.this.capacity_type
    instance_types = aws_eks_node_group.this.instance_types
    ami_type       = aws_eks_node_group.this.ami_type
    disk_size      = aws_eks_node_group.this.disk_size
    remote_access  = aws_eks_node_group.this.remote_access
  }
}