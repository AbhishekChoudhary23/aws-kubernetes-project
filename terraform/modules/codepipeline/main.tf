resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "${var.project_name}-${var.environment}-pipeline-artifacts"
  force_destroy = true

  tags = {
    Name = "${var.project_name}-${var.environment}-pipeline-artifacts"
  }
}

resource "aws_s3_bucket_versioning" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "pipeline_artifacts" {
  bucket = aws_s3_bucket.pipeline_artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_secretsmanager_secret" "github_token" {
  name                    = "${var.project_name}-${var.environment}-github-token"
  description             = "GitHub Personal Access Token for GitOps repository updates"
  recovery_window_in_days = 0
}

resource "aws_codebuild_project" "app" {
  name          = "${var.project_name}-${var.environment}-build"
  description   = "Builds Docker images, pushes to Amazon ECR, and updates GitOps repo"
  service_role  = var.codebuild_role_arn
  build_timeout = 30

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.account_id
    }

    environment_variable {
      name  = "BACKEND_REPO_URI"
      value = var.backend_repository_uri
    }

    environment_variable {
      name  = "FRONTEND_REPO_URI"
      value = var.frontend_repository_uri
    }

    environment_variable {
      name  = "GITOPS_REPO"
      value = var.gitops_repo
    }

    environment_variable {
      name  = "GITOPS_BRANCH"
      value = var.gitops_branch
    }

    environment_variable {
      name  = "GITHUB_TOKEN_SECRET"
      value = aws_secretsmanager_secret.github_token.name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "application/buildspec.yaml"
  }
}

resource "aws_codepipeline" "app" {
  name     = "${var.project_name}-${var.environment}-pipeline"
  role_arn = var.codepipeline_role_arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = "${var.github_owner}/${var.github_repo}"
        BranchName       = var.github_branch
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "BuildAndPushECR"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.app.name
      }
    }
  }
}
