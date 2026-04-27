# Security group for Aurora cluster
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for Aurora PostgreSQL cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
    description     = "PostgreSQL from Lambda"
  }

  tags = { Name = "${var.project_name}-rds-sg" }
}

# Aurora requires a subnet group with at least 2 AZs
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "${var.project_name}-db-subnet-group" }
}

resource "aws_rds_cluster" "main" {
  cluster_identifier      = "${var.project_name}-db"
  engine                  = "aurora-postgresql"
  engine_version          = "16.6"
  engine_mode             = "provisioned"
  database_name           = "npteldb"
  master_username         = "npteladmin"
  master_password         = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  skip_final_snapshot     = true
  deletion_protection     = false
  enable_http_endpoint    = true

  serverlessv2_scaling_configuration {
    min_capacity = 0
    max_capacity = 1.0
  }

  tags = { Name = "${var.project_name}-db" }
}

resource "aws_rds_cluster_instance" "main" {
  cluster_identifier = aws_rds_cluster.main.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.main.engine
  engine_version     = aws_rds_cluster.main.engine_version

  tags = { Name = "${var.project_name}-db-instance" }
}
