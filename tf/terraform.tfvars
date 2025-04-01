# AWS Region
aws_region = "eu-north-1"

# Environment
environment = "production"

# Domain and DNS
domain_name    = "stockpnl.com"
hosted_zone_id = "Z022564630P941WV72XMM"

# VPC Configuration
vpc_name           = "stockpnl-vpc"
vpc_cidr           = "10.0.0.0/16"
azs                = ["eu-north-1a", "eu-north-1b"]
public_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets    = ["10.0.11.0/24", "10.0.12.0/24"]
enable_nat_gateway = true
single_nat_gateway = true

# EKS
eks_cluster_name = "stockpnl-eks"
cluster_name     = "stockpnl-eks"

# S3
bucket_name = "stockpnl-data"

# IAM
iam_role_name             = "stockpnl-ec2-role"
iam_instance_profile_name = "stockpnl-ec2-profile"

# EC2
linux_ami      = "ami-0f65a9eac3c203b54"   # Amazon Linux 2 in eu-north-1
windows_ami    = "ami-01727d3e89897c9c3"   # Windows Server 2019 in eu-north-1
instance_type  = "t3.micro"
linux_name     = "stockpnl-linux"
windows_name   = "stockpnl-windows"

acm_cert_id = "3f05f383-36e1-4b11-8520-c51a378d9631"


argocd_hostname      = "argocd.stockpnl.com"
nginx_hostname       = "stockpnl.com"
alb_zone_id          = "Z23TAZ6LKFMNIO"
