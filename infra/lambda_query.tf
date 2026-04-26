data "archive_file" "query" {
  type        = "zip"
  source_file = "${path.root}/lambda/query/handler.py"
  output_path = "${path.root}/.terraform/lambda_zips/query.zip"
}

resource "aws_lambda_function" "query" {
  function_name    = "${var.project_name}-query"
  filename         = data.archive_file.query.output_path
  source_code_hash = data.archive_file.query.output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_query.arn
  timeout          = 60
  memory_size      = 256

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = aws_bedrockagent_knowledge_base.main.id
      MODEL_ID          = var.bedrock_llm_model_id
      AWS_REGION_NAME   = var.aws_region
    }
  }

  tags = { Name = "${var.project_name}-query" }
}
