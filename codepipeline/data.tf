data "aws_caller_identity" "current" {}

data "aws_secretsmanager_secret" "dockerhub_password" {
  name = "dockerhub_password"
}

data "aws_secretsmanager_secret_version" "dockerhub_password" {
  secret_id = data.aws_secretsmanager_secret.dockerhub_password.id
}

data "aws_secretsmanager_secret" "github_token" {
  name = "github_token"
}

data "aws_secretsmanager_secret_version" "github_token" {
  secret_id = data.aws_secretsmanager_secret.github_token.id
}

data "aws_codestarconnections_connection" "github" {
  name = "my-github-connection"
}