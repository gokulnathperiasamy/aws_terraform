resource "aws_secretsmanager_secret" "api_key" {
  name                    = "${var.project_name}-api-key-${random_id.suffix.hex}"
  description             = "Secret key for PDF chatbot API authentication"
  recovery_window_in_days = 0

  tags = { Name = "${var.project_name}-api-key" }
}

resource "aws_secretsmanager_secret_version" "api_key" {
  secret_id     = aws_secretsmanager_secret.api_key.id
  secret_string = jsonencode({ api_key = var.api_secret_key })
}

# DB credentials secret for Bedrock KB RDS access
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "${var.project_name}-db-credentials-${random_id.suffix.hex}"
  description             = "RDS credentials for Bedrock Knowledge Base"
  recovery_window_in_days = 0

  tags = { Name = "${var.project_name}-db-credentials" }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = aws_rds_cluster.main.master_username
    password = var.db_password
  })
}
