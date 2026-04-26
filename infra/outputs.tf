output "website_url" {
  description = "CloudFront URL for the chatbot webpage"
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}

output "api_gateway_invoke_url" {
  description = "API Gateway invoke URL for chat"
  value       = "${aws_api_gateway_stage.main.invoke_url}/chat"
}

output "api_gateway_ingest_url" {
  description = "API Gateway invoke URL to trigger ingestion"
  value       = "${aws_api_gateway_stage.main.invoke_url}/ingest"
}

output "s3_bucket_name" {
  description = "S3 bucket storing raw PDFs"
  value       = aws_s3_bucket.raw_data.bucket
}

output "knowledge_base_id" {
  description = "Bedrock Knowledge Base ID"
  value       = aws_bedrockagent_knowledge_base.main.id
}

output "codepipeline_name" {
  description = "CodePipeline name"
  value       = aws_codepipeline.main.name
}

output "ssm_tfvars_param" {
  description = "SSM parameter path storing terraform.tfvars — update this if variables change"
  value       = aws_ssm_parameter.tfvars.name
}

output "usage_example" {
  description = "Example curl command to query the chatbot"
  value       = "curl -X POST ${aws_api_gateway_stage.main.invoke_url}/chat -H 'x-api-key: <your-secret>' -H 'Content-Type: application/json' -d '{\"question\": \"What is covered in Week 1?\"}'"
}
