# RDS PostgreSQL Configuration
# Phase 2: Infrastructure Setup

# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name        = "${var.project_name}-db-subnet-group"
    Environment = var.environment
    Project     = var.project_name
  }
}

# RDS Parameter Group
resource "aws_db_parameter_group" "main" {
  family = "postgres14"
  name   = "${var.project_name}-db-params"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  parameter {
    name  = "log_checkpoints"
    value = "1"
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "log_lock_waits"
    value = "1"
  }

  tags = {
    Name        = "${var.project_name}-db-params"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Random password for RDS
resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Store RDS password in AWS Systems Manager Parameter Store
resource "aws_ssm_parameter" "db_password" {
  name        = "/${var.project_name}/database/password"
  description = "Database password for ${var.project_name}"
  type        = "SecureString"
  value       = random_password.db_password.result

  tags = {
    Name        = "${var.project_name}-db-password"
    Environment = var.environment
    Project     = var.project_name
  }
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-database"
  engine         = "postgres"
  engine_version = "14.9"
  instance_class = var.database_instance_class

  allocated_storage     = var.database_allocated_storage
  max_allocated_storage = var.database_max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "django_db"
  username = "django_user"
  password = random_password.db_password.result

  vpc_security_group_ids = [aws_security_group.database.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name

  backup_retention_period = var.database_backup_retention_period
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"

  multi_az               = var.database_multi_az
  publicly_accessible    = false
  copy_tags_to_snapshot  = true
  delete_automated_backups = false

  # Enhanced Monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn

  # Performance Insights
  performance_insights_enabled = true
  performance_insights_retention_period = 7

  # CloudWatch Logs
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # Prevent accidental deletion
  deletion_protection = var.database_deletion_protection
  skip_final_snapshot = var.environment == "production" ? false : true
  final_snapshot_identifier = var.environment == "production" ? "${var.project_name}-final-snapshot-${formatdate("YYYY-MM-DD-hhmm", timestamp())}" : null

  tags = {
    Name        = "${var.project_name}-database"
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM Role for RDS Enhanced Monitoring
resource "aws_iam_role" "rds_monitoring" {
  name = "${var.project_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-rds-monitoring-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Attach AWS managed policy for RDS Enhanced Monitoring
resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch Log Group for RDS
resource "aws_cloudwatch_log_group" "rds" {
  name              = "/aws/rds/instance/${var.project_name}-database/postgresql"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-rds-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# RDS Snapshots for backup
resource "aws_db_snapshot" "initial" {
  count                  = var.create_initial_snapshot ? 1 : 0
  db_instance_identifier = aws_db_instance.main.id
  db_snapshot_identifier = "${var.project_name}-initial-snapshot"

  tags = {
    Name        = "${var.project_name}-initial-snapshot"
    Environment = var.environment
    Type        = "Initial"
  }
}

# Store RDS endpoint in SSM Parameter Store
resource "aws_ssm_parameter" "db_endpoint" {
  name        = "/${var.project_name}/database/endpoint"
  description = "Database endpoint for ${var.project_name}"
  type        = "String"
  value       = aws_db_instance.main.endpoint

  tags = {
    Name        = "${var.project_name}-db-endpoint"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Store database URL in SSM Parameter Store
resource "aws_ssm_parameter" "database_url" {
  name        = "/${var.project_name}/database/url"
  description = "Complete database URL for ${var.project_name}"
  type        = "SecureString"
  value       = "postgresql://django_user:${random_password.db_password.result}@${aws_db_instance.main.endpoint}:${aws_db_instance.main.port}/django_db"

  tags = {
    Name        = "${var.project_name}-database-url"
    Environment = var.environment
    Project     = var.project_name
  }
} 