resource "aws_s3_bucket" "website" {
  bucket        = "${var.project_name}-website-${random_id.suffix.hex}"
  force_destroy = true

  tags = { Name = "${var.project_name}-website" }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontOAC"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.website.arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.website.arn
        }
      }
    }]
  })
}

locals {
  index_html_raw      = file("${path.root}/webpage/index.html")
  api_url_placeholder = "https://chat-uri.execute-api.us-east-1.amazonaws.com/v1/chat"
  api_url_actual      = "${aws_api_gateway_stage.main.invoke_url}/chat"
  index_html_rendered = replace(local.index_html_raw, local.api_url_placeholder, local.api_url_actual)
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content      = local.index_html_rendered
  content_type = "text/html"
  etag         = md5(local.index_html_rendered)
}
