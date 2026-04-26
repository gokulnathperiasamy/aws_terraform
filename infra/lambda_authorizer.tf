data "archive_file" "authorizer" {
  type        = "zip"
  source_file = "${path.root}/lambda/authorizer/handler.py"
  output_path = "${path.root}/.terraform/lambda_zips/authorizer.zip"
}

resource "aws_lambda_function" "authorizer" {
  function_name    = "${var.project_name}-authorizer"
  filename         = data.archive_file.authorizer.output_path
  source_code_hash = data.archive_file.authorizer.output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_authorizer.arn
  timeout          = 10
  memory_size      = 128

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      SECRET_ARN = aws_secretsmanager_secret.api_key.arn
    }
  }

  tags = { Name = "${var.project_name}-authorizer" }
}

resource "aws_lambda_permission" "apigw_invoke_authorizer" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}
