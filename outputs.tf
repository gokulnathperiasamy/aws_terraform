output "website_url" {
  description = "CloudFront URL for the chatbot webpage"
  value       = module.nptel_chatbot.website_url
}

output "api_gateway_invoke_url" {
  description = "API Gateway invoke URL for chat"
  value       = module.nptel_chatbot.api_gateway_invoke_url
}

output "api_gateway_ingest_url" {
  description = "API Gateway invoke URL to trigger ingestion"
  value       = module.nptel_chatbot.api_gateway_ingest_url
}

output "s3_bucket_name" {
  description = "S3 bucket storing raw PDFs"
  value       = module.nptel_chatbot.s3_bucket_name
}

output "knowledge_base_id" {
  description = "Bedrock Knowledge Base ID"
  value       = module.nptel_chatbot.knowledge_base_id
}

output "codepipeline_name" {
  description = "CodePipeline name"
  value       = module.nptel_chatbot.codepipeline_name
}

output "ssm_tfvars_param" {
  description = "SSM parameter path storing terraform.tfvars"
  value       = module.nptel_chatbot.ssm_tfvars_param
}

output "codecommit_clone_url_http" {
  description = "CodeCommit HTTP clone URL"
  value       = module.nptel_chatbot.codecommit_clone_url_http
}

output "usage_example" {
  description = "Example curl command to query the chatbot"
  value       = module.nptel_chatbot.usage_example
}
