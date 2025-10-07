resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = var.node_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      }
    ])

    mapUsers    = var.map_users != null ? yamlencode(var.map_users) : ""
    mapAccounts = var.map_accounts != null ? yamlencode(var.map_accounts) : ""
  }

  force      = true
  depends_on = [var.cluster_id]
}