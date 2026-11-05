# ─── S3 Bucket for Pipeline Artifacts ────────────────────
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

# ─── Secrets Manager for GitHub Token ────────────────────
resource "aws_secretsmanager_secret" "github_token" {
  name                    = "${var.project_name}/github-token"
  description             = "GitHub PAT for pushing to GitOps repo"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-${var.environment}-github-token"
  }
}

# ─── CodeBuild Project ──────────────────────────────────
resource "aws_codebuild_project" "app" {
  name         = "${var.project_name}-${var.environment}-build"
  service_role = var.codebuild_role_arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.account_id
    }

    environment_variable {
      name  = "BACKEND_ECR_URI"
      value = var.backend_repository_uri
    }

    environment_variable {
      name  = "FRONTEND_ECR_URI"
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
    buildspec = "buildspec.yml"
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_name}-${var.environment}"
      stream_name = "build"
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-codebuild"
  }
}

# ─── CodePipeline ────────────────────────────────────────
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
      provider = "CodeStarSourceConnection"
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
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.app.name
      }
    }
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-pipeline"
  }
}