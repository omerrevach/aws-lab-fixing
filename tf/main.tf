module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.1.0"

  name                = var.vpc_name
  cidr                = var.vpc_cidr
  azs                 = var.azs
  public_subnets      = var.public_subnets
  private_subnets     = var.private_subnets

  enable_nat_gateway  = true
  single_nat_gateway  = true
  one_nat_gateway_per_az = false  # still uses one unless you want per-AZ

    public_subnet_tags = {
    "kubernetes.io/role/elb"                         = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}"  = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"                = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}"  = "shared"
  }

  tags = {
    Name        = var.vpc_name
    Environment = var.environment
    Terraform   = "true"
  }
}


module "s3_bucket" {
  source      = "./modules/s3"
  bucket_name = var.bucket_name
}

module "iam" {
  source                    = "./modules/iam"
  iam_role_name             = var.iam_role_name
  iam_instance_profile_name = var.iam_instance_profile_name
  s3_bucket_arn             = module.s3_bucket.bucket_arn
  vpc_id                    = module.vpc.vpc_id
}

module "eks" {
  source                            = "./modules/eks"
  cluster_name                      = var.eks_cluster_name
  vpc_id                            = module.vpc.vpc_id
  private_subnets                   = module.vpc.private_subnets
  eks_fargate_pod_execution_role_arn = module.iam.eks_fargate_pod_execution_role_arn
  ec2_ssm_role_arn                    = module.iam.ec2_ssm_role_arn
}

module "eks_blueprints_addons" {
  source = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = "1.31"
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_ingress_nginx                = false

  enable_argocd                       = false

  enable_aws_load_balancer_controller    = true
  aws_load_balancer_controller = {
    set = [
      {
        name  = "vpcId"
        value = module.vpc.vpc_id
      },
      {
        name  = "region"
        value = var.aws_region
      },
    ]
  }

  tags = { Environment = "prod" }

  depends_on = [module.eks]
}

module "ec2" {
  source               = "./modules/ec2"
  linux_ami            = var.linux_ami
  windows_ami          = var.windows_ami
  instance_type        = var.instance_type
  private_subnets      = module.vpc.private_subnets
  iam_instance_profile = module.iam.ec2_instance_profile
  linux_name           = var.linux_name
  windows_name         = var.windows_name
  k8s_version          = "1.31.0"
  k8s_build            = "2024-03-15"
  vpc_id               = module.vpc.vpc_id
  
  eks_cluster_name     = var.eks_cluster_name
  eks_cluster_endpoint = module.eks.cluster_endpoint
  eks_cluster_ca_data  = module.eks.cluster_certificate_authority_data
  aws_region           = var.aws_region
}

resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode([
      {
        rolearn  = module.iam.ec2_ssm_role_arn
        username = "ec2-user"
        groups   = ["system:masters"]
      }
    ])
  }

  depends_on = [module.eks]
}
