resource "aws_s3_bucket" "raw_data" {
  bucket        = "${var.project_name}-raw-data-${random_id.suffix.hex}"
  force_destroy = true

  tags = { Name = "${var.project_name}-raw-data" }
}

resource "aws_s3_bucket_versioning" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "raw_data" {
  bucket = aws_s3_bucket.raw_data.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "raw_data" {
  bucket                  = aws_s3_bucket.raw_data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload all PDFs from source_data/
resource "aws_s3_object" "pdfs" {
  for_each = fileset("${path.root}/source_data", "*.pdf")

  bucket       = aws_s3_bucket.raw_data.id
  key          = "documents/${each.value}"
  source       = "${path.root}/source_data/${each.value}"
  content_type = "application/pdf"

  lifecycle {
    ignore_changes = [etag]
  }
}

# Notification to trigger ingestion Lambda on new PDF uploads
resource "aws_s3_bucket_notification" "pdf_upload" {
  bucket = aws_s3_bucket.raw_data.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.ingestion.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "documents/"
    filter_suffix       = ".pdf"
  }

  depends_on = [aws_lambda_permission.s3_invoke_ingestion]
}
