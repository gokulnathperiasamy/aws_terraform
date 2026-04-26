# ── CodeBuild Role ────────────────────────────────────────────────────────────
resource "aws_iam_role" "codebuild" {
  name = "${var.project_name}-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  name = "${var.project_name}-codebuild-policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Logs"
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/codebuild/${var.project_name}-*"
      },
      {
        Sid      = "ArtifactsBucket"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:GetObjectVersion"]
        Resource = "${aws_s3_bucket.pipeline_artifacts.arn}/*"
      },
      {
        Sid      = "SSMTfvars"
        Effect   = "Allow"
        Action   = ["ssm:GetParameter"]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/tfvars"
      },
      {
        Sid      = "TerraformStateS3"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = ["${aws_s3_bucket.raw_data.arn}", "${aws_s3_bucket.raw_data.arn}/*"]
      },
      {
        Sid    = "TerraformProvision"
        Effect = "Allow"
        Action = ["*"]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      }
    ]
  })
}

# ── CodePipeline Role ─────────────────────────────────────────────────────────
resource "aws_iam_role" "codepipeline" {
  name = "${var.project_name}-codepipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "codepipeline" {
  name = "${var.project_name}-codepipeline-policy"
  role = aws_iam_role.codepipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ArtifactsBucket"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:GetBucketVersioning", "s3:GetObjectVersion"]
        Resource = [
          aws_s3_bucket.pipeline_artifacts.arn,
          "${aws_s3_bucket.pipeline_artifacts.arn}/*"
        ]
      },
      {
        Sid      = "CodeCommitSource"
        Effect   = "Allow"
        Action   = ["codecommit:GetBranch", "codecommit:GetCommit", "codecommit:UploadArchive", "codecommit:GetUploadArchiveStatus", "codecommit:CancelUploadArchive"]
        Resource = aws_codecommit_repository.main.arn
      },
      {
        Sid      = "CodeBuildTrigger"
        Effect   = "Allow"
        Action   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
        Resource = aws_codebuild_project.terraform_apply.arn
      }
    ]
  })
}

# ── EventBridge Role ──────────────────────────────────────────────────────────
resource "aws_iam_role" "eventbridge_pipeline" {
  name = "${var.project_name}-eventbridge-pipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "eventbridge_pipeline" {
  name = "${var.project_name}-eventbridge-pipeline-policy"
  role = aws_iam_role.eventbridge_pipeline.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["codepipeline:StartPipelineExecution"]
      Resource = aws_codepipeline.main.arn
    }]
  })
}
