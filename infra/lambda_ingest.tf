data "archive_file" "ingest" {
  type        = "zip"
  source_file = "${path.root}/lambda/ingest/handler.py"
  output_path = "${path.root}/.terraform/lambda_zips/ingest.zip"
}

resource "aws_iam_role" "lambda_ingest" {
  name = "${var.project_name}-lambda-ingest-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_ingest_vpc" {
  role       = aws_iam_role.lambda_ingest.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_ingest" {
  name = "${var.project_name}-lambda-ingest-policy"
  role = aws_iam_role.lambda_ingest.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["bedrock:StartIngestionJob", "bedrock:GetIngestionJob"]
      Resource = "*"
    }]
  })
}

resource "aws_lambda_function" "ingest" {
  function_name    = "${var.project_name}-ingest"
  filename         = data.archive_file.ingest.output_path
  source_code_hash = data.archive_file.ingest.output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_ingest.arn
  timeout          = 30
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

  tags = { Name = "${var.project_name}-ingest" }
}

resource "aws_lambda_permission" "apigw_invoke_ingest" {
  statement_id  = "AllowAPIGatewayInvokeIngest"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingest.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}
