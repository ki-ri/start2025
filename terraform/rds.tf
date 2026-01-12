# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.repository_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = merge(
    var.common_tags,
    {
      Name = "${var.repository_name}-db-subnet-group"
    }
  )
}

# Random password for RDS
resource "random_password" "db_password" {
  length  = 16
  special = true
  # Exclude characters that might cause issues in connection strings
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  identifier     = "${var.repository_name}-db"
  engine         = "postgres"
  engine_version = "16.4"
  instance_class = var.db_instance_class

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password != "" ? var.db_password : random_password.db_password.result

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  backup_retention_period = var.db_backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  skip_final_snapshot       = true
  final_snapshot_identifier = "${var.repository_name}-db-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  tags = merge(
    var.common_tags,
    {
      Name = "${var.repository_name}-db"
    }
  )
}

# Store DB password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.repository_name}-db-password"
  recovery_window_in_days = 7

  tags = merge(
    var.common_tags,
    {
      Name = "${var.repository_name}-db-password"
    }
  )
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username            = var.db_username
    password            = var.db_password != "" ? var.db_password : random_password.db_password.result
    engine              = "postgres"
    host                = aws_db_instance.main.address
    port                = aws_db_instance.main.port
    dbname              = var.db_name
    dbInstanceIdentifier = aws_db_instance.main.id
  })
}
