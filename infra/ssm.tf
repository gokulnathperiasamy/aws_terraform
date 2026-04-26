resource "aws_ssm_parameter" "tfvars" {
  name        = "/${var.project_name}/tfvars"
  description = "terraform.tfvars content for CodeBuild pipeline"
  type        = "SecureString"
  value       = <<-EOT
    aws_region     = "${var.aws_region}"
    project_name   = "${var.project_name}"
    api_secret_key = "${var.api_secret_key}"
  EOT

  tags = { Name = "${var.project_name}-tfvars" }

  lifecycle {
    ignore_changes = [value]
  }
}
