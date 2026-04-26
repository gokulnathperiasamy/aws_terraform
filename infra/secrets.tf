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
