# Create the vector index in AOSS before Bedrock KB is created
resource "null_resource" "aoss_index" {
  provisioner "local-exec" {
    command = "python3 ${path.root}/scripts/create_aoss_index.py ${aws_opensearchserverless_collection.main.collection_endpoint} ${var.aws_region}"
  }

  depends_on = [aws_opensearchserverless_access_policy.main]
}

resource "aws_bedrockagent_knowledge_base" "main" {
  name     = "${var.project_name}-kb"
  role_arn = aws_iam_role.bedrock_kb.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = var.bedrock_embedding_model_arn
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.main.arn
      vector_index_name = "bedrock-knowledge-base-index"
      field_mapping {
        vector_field   = "bedrock-knowledge-base-default-vector"
        text_field     = "AMAZON_BEDROCK_TEXT_CHUNK"
        metadata_field = "AMAZON_BEDROCK_METADATA"
      }
    }
  }

  depends_on = [aws_opensearchserverless_access_policy.main, null_resource.aoss_index]

  tags = { Name = "${var.project_name}-kb" }
}

resource "aws_bedrockagent_data_source" "s3" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.main.id
  name              = "${var.project_name}-s3-datasource"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn         = aws_s3_bucket.raw_data.arn
      inclusion_prefixes = ["documents/"]
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens         = 512
        overlap_percentage = 20
      }
    }
  }
}
