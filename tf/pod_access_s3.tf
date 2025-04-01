#  IAM role for app
resource "aws_iam_role" "flask_app_role" {
  name = "flask-app-s3-role"
  
  # The Condition.StringEquals makes sure only the service account named flask-app-sa in the default namespace can assume this role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = module.eks.oidc_provider_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(module.eks.oidc_provider_arn, "/^(.*provider\\/)/", "")}:sub": "system:serviceaccount:default:flask-app-sa",
            "${replace(module.eks.oidc_provider_arn, "/^(.*provider\\/)/", "")}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# IAM policy for S3 access
resource "aws_iam_policy" "flask_app_s3_policy" {
  name        = "flask-app-s3-policy"
  description = "Allow Flask app to access stockpnl-data S3 bucket"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ],
        Resource = [
          "arn:aws:s3:::stockpnl-data",
          "arn:aws:s3:::stockpnl-data/*"
        ]
      }
    ]
  })
}

# Attach policy to the role
resource "aws_iam_role_policy_attachment" "flask_app_s3_attachment" {
  role       = aws_iam_role.flask_app_role.name
  policy_arn = aws_iam_policy.flask_app_s3_policy.arn
}

# Create the Kubernetes service account
resource "kubernetes_service_account" "flask_app_sa" {
  depends_on = [module.eks, aws_iam_role.flask_app_role]
  
  metadata {
    name      = "flask-app-sa"
    namespace = "default"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.flask_app_role.arn
    }
  }
}