data "aws_caller_identity" "current" {}

# ── Bedrock Knowledge Base Role ──────────────────────────────────────────────
resource "aws_iam_role" "bedrock_kb" {
  name = "${var.project_name}-bedrock-kb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
}

resource "aws_iam_role_policy" "bedrock_kb" {
  name = "${var.project_name}-bedrock-kb-policy"
  role = aws_iam_role.bedrock_kb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [aws_s3_bucket.raw_data.arn, "${aws_s3_bucket.raw_data.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = [var.bedrock_embedding_model_arn]
      },
      {
        Effect = "Allow"
        Action = [
          "aoss:APIAccessAll"
        ]
        Resource = [aws_opensearchserverless_collection.main.arn]
      }
    ]
  })
}

# ── Lambda Base Role (shared) ─────────────────────────────────────────────────
resource "aws_iam_role" "lambda_base" {
  name = "${var.project_name}-lambda-base-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_base.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ── Query Lambda Role ─────────────────────────────────────────────────────────
resource "aws_iam_role" "lambda_query" {
  name = "${var.project_name}-lambda-query-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_query_vpc" {
  role       = aws_iam_role.lambda_query.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_query" {
  name = "${var.project_name}-lambda-query-policy"
  role = aws_iam_role.lambda_query.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["bedrock:Retrieve"]
        Resource = "arn:aws:bedrock:${var.aws_region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${var.aws_region}::foundation-model/${var.bedrock_llm_model_id}"
      }
    ]
  })
}

# ── Authorizer Lambda Role ────────────────────────────────────────────────────
resource "aws_iam_role" "lambda_authorizer" {
  name = "${var.project_name}-lambda-authorizer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_authorizer_vpc" {
  role       = aws_iam_role.lambda_authorizer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_authorizer" {
  name = "${var.project_name}-lambda-authorizer-policy"
  role = aws_iam_role.lambda_authorizer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = [aws_secretsmanager_secret.api_key.arn]
      }
    ]
  })
}

# ── Ingestion Lambda Role ─────────────────────────────────────────────────────
resource "aws_iam_role" "lambda_ingestion" {
  name = "${var.project_name}-lambda-ingestion-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_ingestion_vpc" {
  role       = aws_iam_role.lambda_ingestion.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_ingestion" {
  name = "${var.project_name}-lambda-ingestion-policy"
  role = aws_iam_role.lambda_ingestion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["bedrock:StartIngestionJob", "bedrock:GetIngestionJob"]
        Resource = "*"
      }
    ]
  })
}
