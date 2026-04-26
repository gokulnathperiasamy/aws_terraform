terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "nptel_chatbot" {
  source = "./infra"

  aws_region                  = var.aws_region
  project_name                = var.project_name
  api_secret_key              = var.api_secret_key
  bedrock_llm_model_id        = var.bedrock_llm_model_id
  bedrock_embedding_model_arn = var.bedrock_embedding_model_arn
  vpc_cidr                    = var.vpc_cidr
  private_subnet_cidrs        = var.private_subnet_cidrs
  availability_zones          = var.availability_zones
}
