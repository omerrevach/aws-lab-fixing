data "aws_caller_identity" "current" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  

  cluster_name    = var.cluster_name
  cluster_version = "1.31"

  vpc_id                  = var.vpc_id
  subnet_ids              = var.private_subnets
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = false

  enable_cluster_creator_admin_permissions = true


#   # Cluster IAM role
#   iam_role_name            = "${var.cluster_name}-eks-cluster"
#   iam_role_use_name_prefix = false
  
  # This is critical - disable aws_auth configmap management

  enable_irsa = true

  cluster_addons = {
    coredns     = { most_recent = true }
    kube-proxy  = { most_recent = true }
    vpc-cni     = { most_recent = true }
  }

  fargate_profiles = {
    default = {
      selectors = [
        { namespace = "default" },
        { namespace = "argocd" },
        { namespace = "ingress" },
        { namespace = "kube-system" }
      ]
      pod_execution_role_arn = var.eks_fargate_pod_execution_role_arn
    }
  }

  tags = { Environment = "prod" }
}

