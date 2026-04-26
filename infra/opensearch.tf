resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "${var.project_name}-enc"
  type        = "encryption"

  policy = jsonencode({
    Rules = [{
      ResourceType = "collection"
      Resource     = ["collection/${var.project_name}-kb"]
    }]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  name        = "${var.project_name}-net"
  type        = "network"

  policy = jsonencode([{
    Rules = [
      {
        ResourceType = "collection"
        Resource     = ["collection/${var.project_name}-kb"]
      },
      {
        ResourceType = "dashboard"
        Resource     = ["collection/${var.project_name}-kb"]
      }
    ]
    AllowFromPublic = true
  }])
}

resource "aws_opensearchserverless_collection" "main" {
  name = "${var.project_name}-kb"
  type = "VECTORSEARCH"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network
  ]

  tags = { Name = "${var.project_name}-kb" }
}

resource "aws_opensearchserverless_access_policy" "main" {
  name = "${var.project_name}-access"
  type = "data"

  policy = jsonencode([{
    Rules = [
      {
        ResourceType = "index"
        Resource     = ["index/${var.project_name}-kb/*"]
        Permission   = ["aoss:CreateIndex", "aoss:DeleteIndex", "aoss:UpdateIndex", "aoss:DescribeIndex", "aoss:ReadDocument", "aoss:WriteDocument"]
      },
      {
        ResourceType = "collection"
        Resource     = ["collection/${var.project_name}-kb"]
        Permission   = ["aoss:CreateCollectionItems", "aoss:DeleteCollectionItems", "aoss:UpdateCollectionItems", "aoss:DescribeCollectionItems"]
      }
    ]
    Principal = [
      aws_iam_role.bedrock_kb.arn,
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
    ]
  }])
}
