output "ec2_instance_profile" {
  value = aws_iam_instance_profile.ec2_instance_profile.name
}

output "ec2_security_group_id" {
  value = aws_security_group.ec2_sg.id
}

output "eks_fargate_pod_execution_role_arn" {
  value = aws_iam_role.eks_fargate_pod_execution_role.arn
}

output "ec2_ssm_role_arn" {
  value       = aws_iam_role.ec2_ssm_role.arn
}


