variable "aws_region" {}
variable "environment" {}
variable "domain_name" {}
variable "hosted_zone_id" {}
variable "vpc_name" {}
variable "vpc_cidr" {}
variable "azs" {
  type        = list(string)
}

variable "public_subnets" {
  type        = list(string)
}

variable "private_subnets" {
  type        = list(string)
}

variable "enable_nat_gateway" {}
variable "single_nat_gateway" {}
variable "eks_cluster_name" {}
variable "bucket_name" {}
variable "iam_role_name" {}
variable "iam_instance_profile_name" {}
variable "linux_ami" {}
variable "windows_ami" {}
variable "instance_type" {}
variable "linux_name" {}
variable "windows_name" {}
variable "cluster_name" {}

variable "acm_cert_id" {}
variable "argocd_hostname" {}
variable "nginx_hostname" {}
variable "alb_zone_id" {}
