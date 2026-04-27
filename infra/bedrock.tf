resource "aws_bedrockagent_knowledge_base" "main" {
  name     = "${var.project_name}-knowledge-base"
  role_arn = aws_iam_role.bedrock_kb.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = var.bedrock_embedding_model_arn
    }
  }

  storage_configuration {
    type = "RDS"
    rds_configuration {
      resource_arn           = aws_rds_cluster.main.arn
      credentials_secret_arn = aws_secretsmanager_secret.db_credentials.arn
      database_name          = aws_rds_cluster.main.database_name
      table_name             = "bedrock_kb_vectors"
      field_mapping {
        vector_field      = "embedding"
        text_field        = "chunks"
        metadata_field    = "metadata"
        primary_key_field = "id"
      }
    }
  }

  depends_on = [aws_rds_cluster_instance.main, null_resource.pgvector_setup]

  tags = { Name = "${var.project_name}-kb" }
}

resource "aws_bedrockagent_data_source" "s3" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.main.id
  name              = "${var.project_name}-knowledge-base-s3-datasource"

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

# Trigger initial ingestion after KB + data source are created
resource "null_resource" "trigger_ingestion" {
  provisioner "local-exec" {
    command = <<-EOT
      aws bedrock-agent start-ingestion-job \
        --knowledge-base-id ${aws_bedrockagent_knowledge_base.main.id} \
        --data-source-id ${aws_bedrockagent_data_source.s3.data_source_id} \
        --region ${var.aws_region}
    EOT
  }

  depends_on = [aws_bedrockagent_data_source.s3]

  triggers = {
    data_source_id    = aws_bedrockagent_data_source.s3.data_source_id
    knowledge_base_id = aws_bedrockagent_knowledge_base.main.id
  }
}
