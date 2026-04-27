# Package psycopg2 as a Lambda layer
data "archive_file" "psycopg2_layer" {
  type        = "zip"
  source_dir  = "${path.root}/lambda/pgvector_setup/layer"
  output_path = "${path.root}/.terraform/lambda_zips/psycopg2_layer.zip"
}

resource "aws_lambda_layer_version" "psycopg2" {
  layer_name          = "${var.project_name}-psycopg2"
  filename            = data.archive_file.psycopg2_layer.output_path
  source_code_hash    = data.archive_file.psycopg2_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
}

# Package the setup handler
data "archive_file" "pgvector_setup" {
  type        = "zip"
  source_file = "${path.root}/lambda/pgvector_setup/handler.py"
  output_path = "${path.root}/.terraform/lambda_zips/pgvector_setup.zip"
}

resource "aws_iam_role" "lambda_pgvector_setup" {
  name = "${var.project_name}-lambda-pgvector-setup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_pgvector_setup_vpc" {
  role       = aws_iam_role.lambda_pgvector_setup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_lambda_function" "pgvector_setup" {
  function_name    = "${var.project_name}-pgvector-setup"
  filename         = data.archive_file.pgvector_setup.output_path
  source_code_hash = data.archive_file.pgvector_setup.output_base64sha256
  handler          = "handler.handler"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda_pgvector_setup.arn
  timeout          = 60
  memory_size      = 128
  layers           = [aws_lambda_layer_version.psycopg2.arn]

  vpc_config {
    subnet_ids         = aws_subnet.private[*].id
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      DB_HOST     = aws_rds_cluster.main.endpoint
      DB_PORT     = tostring(aws_rds_cluster.main.port)
      DB_NAME     = aws_rds_cluster.main.database_name
      DB_USER     = aws_rds_cluster.main.master_username
      DB_PASSWORD = var.db_password
    }
  }

  tags = { Name = "${var.project_name}-pgvector-setup" }
}

# Invoke the Lambda once after it's created
resource "null_resource" "pgvector_setup" {
  provisioner "local-exec" {
    command = <<-EOT
      aws lambda invoke \
        --function-name ${aws_lambda_function.pgvector_setup.function_name} \
        --region ${var.aws_region} \
        --payload '{}' \
        --cli-binary-format raw-in-base64-out \
        /tmp/pgvector_setup_response.json && \
      cat /tmp/pgvector_setup_response.json
    EOT
  }

  depends_on = [aws_lambda_function.pgvector_setup, aws_rds_cluster_instance.main]

  triggers = {
    db_cluster_id = aws_rds_cluster.main.id
  }
}
