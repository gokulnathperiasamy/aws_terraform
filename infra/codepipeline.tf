# ── Artifact Bucket ───────────────────────────────────────────────────────────
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket        = "${var.project_name}-pipeline-artifacts-${random_id.suffix.hex}"
  force_destroy = true

  tags = { Name = "${var.project_name}-pipeline-artifacts" }
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
  bucket                  = aws_s3_bucket.pipeline_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── CodeBuild Project ─────────────────────────────────────────────────────────
resource "aws_codebuild_project" "terraform_apply" {
  name          = "${var.project_name}-terraform-apply"
  description   = "Runs terraform init and apply on tag-based pipeline trigger"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 60

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "TF_VAR_FILE_PARAM"
      value = "/${var.project_name}/tfvars"
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "AWS_REGION_NAME"
      value = var.aws_region
      type  = "PLAINTEXT"
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name  = "/aws/codebuild/${var.project_name}-terraform-apply"
      stream_name = "build"
    }
  }

  tags = { Name = "${var.project_name}-terraform-apply" }
}

# ── CodePipeline ──────────────────────────────────────────────────────────────
resource "aws_codepipeline" "main" {
  name     = "${var.project_name}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

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
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName       = aws_codecommit_repository.main.repository_name
        BranchName           = "main"
        PollForSourceChanges = "false"
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "TerraformApply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output"]

      configuration = {
        ProjectName = aws_codebuild_project.terraform_apply.name
      }
    }
  }

  tags = { Name = "${var.project_name}-pipeline" }
}

# ── EventBridge Rule — trigger pipeline on tag deploy-changes-* ───────────────
resource "aws_cloudwatch_event_rule" "deploy_tag" {
  name        = "${var.project_name}-deploy-tag-trigger"
  description = "Triggers CodePipeline when a tag matching deploy-changes-* is pushed to CodeCommit"

  event_pattern = jsonencode({
    source      = ["aws.codecommit"]
    detail-type = ["CodeCommit Repository State Change"]
    resources   = [aws_codecommit_repository.main.arn]
    detail = {
      event         = ["referenceCreated"]
      referenceType = ["tag"]
      referenceName = [{ prefix = "deploy-changes-" }]
    }
  })

  tags = { Name = "${var.project_name}-deploy-tag-trigger" }
}

resource "aws_cloudwatch_event_target" "deploy_tag_pipeline" {
  rule     = aws_cloudwatch_event_rule.deploy_tag.name
  arn      = aws_codepipeline.main.arn
  role_arn = aws_iam_role.eventbridge_pipeline.arn
}
