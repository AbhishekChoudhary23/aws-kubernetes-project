output "pipeline_name" {
  value = aws_codepipeline.app.name
}

output "codebuild_project_name" {
  value = aws_codebuild_project.app.name
}

output "artifacts_bucket" {
  value = aws_s3_bucket.pipeline_artifacts.bucket
}

output "github_token_secret_name" {
  value = aws_secretsmanager_secret.github_token.name
}