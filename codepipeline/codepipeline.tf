resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = var.pipeline_artifact_bucket
  tags = {
    Name = "pipeline-artifacts"
    Environment = "prod"
  }
}

resource "aws_codepipeline" "lab_pipeline" {
  name = "lab-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn
  
  artifact_store {
    type = "S3"
    location = aws_s3_bucket.pipeline_artifacts.bucket
  }
  
  stage {
    name = "Source"
    action {
      name = "GitHub_Source"
      category = "Source"
      owner = "AWS"
      provider = "CodeStarSourceConnection"
      version = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn = data.aws_codestarconnections_connection.github.arn
        FullRepositoryId = "omerrevach/aws-lab"
        BranchName = "lab-pipeline"
        DetectChanges = "true"
      }
    }
  }
  
  stage {
    name = "Build"
    action {
      name = "BuildAction"
      category = "Build"
      owner = "AWS"
      provider = "CodeBuild"
      version = "1"
      input_artifacts = ["source_output"]
      output_artifacts = []
      configuration = {
        ProjectName = aws_codebuild_project.lab_app_build.name
      }
    }
  }
}