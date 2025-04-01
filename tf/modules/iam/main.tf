# IAM Role for EC2 (SSM, EKS, Kubernetes API access)
resource "aws_iam_role" "ec2_ssm_role" {
  name = var.iam_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
      Effect    = "Allow"
    }]
  })
}

# Attach AmazonSSM policy to EC2
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach EKS read-only policy to EC2
resource "aws_iam_role_policy_attachment" "eks_read_only" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Custom policy for EC2 instance to access EKS cluster
resource "aws_iam_policy" "eks_access" {
  name        = "eks-ec2-cluster-access-policy"
  description = "Policy for EC2 instance to interact with EKS cluster"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:ListFargateProfiles",
          "eks:ListUpdates",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_access" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = aws_iam_policy.eks_access.arn
}

# EC2 Instance profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = var.iam_instance_profile_name
  role = aws_iam_role.ec2_ssm_role.name
}

# Security Group for EC2 instance
resource "aws_security_group" "ec2_sg" {
  name   = "ec2-ssm-sg"
  vpc_id = var.vpc_id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#############################################
# IAM Role for EKS Fargate Pod Execution
#############################################

resource "aws_iam_role" "eks_fargate_pod_execution_role" {
  name = "eks-fargate-pod-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "eks-fargate-pods.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "fargate_execution" {
  role       = aws_iam_role.eks_fargate_pod_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "fargate_cni" {
  role       = aws_iam_role.eks_fargate_pod_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "fargate_ecr" {
  role       = aws_iam_role.eks_fargate_pod_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Custom policy for EKS Fargate pods to access S3 bucket
resource "aws_iam_policy" "fargate_s3_access" {
  name        = "eks-fargate-s3-access-policy"
  description = "Allows EKS Fargate pods to ListBucket and GetObject from S3"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = [var.s3_bucket_arn]
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = ["${var.s3_bucket_arn}/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "fargate_s3_access_attachment" {
  role       = aws_iam_role.eks_fargate_pod_execution_role.name
  policy_arn = aws_iam_policy.fargate_s3_access.arn
}

