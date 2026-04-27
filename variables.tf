variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "nptel-qa-iot-2026"
}

variable "api_secret_key" {
  description = "Secret key required in x-api-key header to invoke the API"
  type        = string
  sensitive   = true
}

variable "bedrock_embedding_model_arn" {
  description = "Bedrock embedding model ARN for Knowledge Base"
  type        = string
  default     = "arn:aws:bedrock:us-east-1::foundation-model/amazon.titan-embed-text-v2:0"
}

variable "bedrock_llm_model_id" {
  description = "Bedrock LLM model ID for generation"
  type        = string
  default     = "openai.gpt-oss-20b-1:0"
}

variable "db_password" {
  description = "RDS PostgreSQL master password"
  type        = string
  sensitive   = true
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}
