variable "cluster_name" {}
variable "vpc_id" {}
variable "private_subnets" {
  type        = list(string)
}
variable "eks_fargate_pod_execution_role_arn" {
  type        = string
  description = "IAM role for EKS Fargate pods"
}
variable "ec2_ssm_role_arn" {
  description = "IAM role for EC2 (SSM)"
  type        = string
}

