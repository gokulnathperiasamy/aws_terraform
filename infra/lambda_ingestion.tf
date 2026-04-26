data "archive_file" "ingestion" {
  type        = "zip"
  source_file = "${path.root}/lambda/ingestion/handler.py"
  output_path = "${path.root}/.terraform/lambda_zips/ingestion.zip"
}

resource "aws_lambda_function" "ingestion" {
  function_name    = "${var.project_name}-ingestion"
  filename         = data.archive_file.ingestion.output_path
  source_code_hash = data.archive_file.ingestion.output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_ingestion.arn
  timeout          = 60
  memory_size      = 128

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      KNOWLEDGE_BASE_ID = aws_bedrockagent_knowledge_base.main.id
      DATA_SOURCE_ID    = aws_bedrockagent_data_source.s3.data_source_id
    }
  }

  tags = { Name = "${var.project_name}-ingestion" }
}

resource "aws_lambda_permission" "s3_invoke_ingestion" {
  statement_id  = "AllowS3InvokeIngestion"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestion.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_data.arn
}
