resource "aws_codecommit_repository" "main" {
  repository_name = var.project_name
  description     = "PDF Chatbot infrastructure and Lambda source code"

  tags = { Name = var.project_name }
}

output "codecommit_clone_url_http" {
  description = "CodeCommit repository HTTP clone URL"
  value       = aws_codecommit_repository.main.clone_url_http
}

output "codecommit_clone_url_ssh" {
  description = "CodeCommit repository SSH clone URL"
  value       = aws_codecommit_repository.main.clone_url_ssh
}
