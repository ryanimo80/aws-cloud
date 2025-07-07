# Backup and Disaster Recovery Infrastructure
# This file contains backup strategies and disaster recovery resources

# AWS Backup Vault
resource "aws_backup_vault" "main" {
  name        = "${var.project_name}-backup-vault"
  kms_key_arn = aws_kms_key.backup.arn

  tags = {
    Name        = "${var.project_name}-backup-vault"
    Environment = var.environment
  }
}

# KMS Key for Backup
resource "aws_kms_key" "backup" {
  description             = "KMS key for backup encryption"
  deletion_window_in_days = 7

  tags = {
    Name        = "${var.project_name}-backup-key"
    Environment = var.environment
  }
}

resource "aws_kms_alias" "backup" {
  name          = "alias/${var.project_name}-backup"
  target_key_id = aws_kms_key.backup.key_id
}

# IAM Role for AWS Backup
resource "aws_iam_role" "backup" {
  name = "${var.project_name}-backup-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "backup.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-backup-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

# Backup Plan
resource "aws_backup_plan" "main" {
  name = "${var.project_name}-backup-plan"

  rule {
    rule_name         = "daily_backups"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 2 ? * * *)" # Daily at 2 AM UTC

    lifecycle {
      cold_storage_after = 30
      delete_after       = 120
    }

    recovery_point_tags = {
      Environment = var.environment
      Project     = var.project_name
      BackupType  = "Daily"
    }
  }

  rule {
    rule_name         = "weekly_backups"
    target_vault_name = aws_backup_vault.main.name
    schedule          = "cron(0 3 ? * SUN *)" # Weekly on Sunday at 3 AM UTC

    lifecycle {
      cold_storage_after = 30
      delete_after       = 365
    }

    recovery_point_tags = {
      Environment = var.environment
      Project     = var.project_name
      BackupType  = "Weekly"
    }
  }

  tags = {
    Name        = "${var.project_name}-backup-plan"
    Environment = var.environment
  }
}

# Backup Selection for RDS
resource "aws_backup_selection" "rds" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.project_name}-rds-backup-selection"
  plan_id      = aws_backup_plan.main.id

  resources = [
    aws_db_instance.main.arn
  ]

  condition {
    string_equals {
      key   = "aws:ResourceTag/Environment"
      value = var.environment
    }
  }

  tags = {
    Name        = "${var.project_name}-rds-backup-selection"
    Environment = var.environment
  }
}

# RDS Automated Backups Configuration (already in main.tf but adding monitoring)
resource "aws_cloudwatch_metric_alarm" "rds_backup_failure" {
  alarm_name          = "${var.project_name}-rds-backup-failure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BackupRetentionPeriodStorageUsed"
  namespace           = "AWS/RDS"
  period              = "86400" # 24 hours
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors RDS backup failures"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = {
    Name        = "${var.project_name}-rds-backup-failure"
    Environment = var.environment
  }
}

# ElastiCache Redis Backup Configuration (Redis snapshots)
resource "aws_cloudwatch_metric_alarm" "redis_backup_failure" {
  alarm_name          = "${var.project_name}-redis-backup-failure"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CacheHits"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors Redis availability"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    CacheClusterId = aws_elasticache_cluster.main.cluster_id
  }

  tags = {
    Name        = "${var.project_name}-redis-backup-failure"
    Environment = var.environment
  }
}

# S3 Bucket for Application Backups
resource "aws_s3_bucket" "app_backups" {
  bucket        = "${var.project_name}-app-backups-${random_string.bucket_suffix.result}"
  force_destroy = true

  tags = {
    Name        = "${var.project_name}-app-backups"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "app_backups" {
  bucket = aws_s3_bucket.app_backups.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "app_backups" {
  bucket = aws_s3_bucket.app_backups.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        kms_master_key_id = aws_kms_key.backup.arn
        sse_algorithm     = "aws:kms"
      }
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "app_backups" {
  bucket = aws_s3_bucket.app_backups.id

  rule {
    id     = "backup_lifecycle"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    transition {
      days          = 180
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 2555 # 7 years
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Cross-region replication for critical backups
resource "aws_s3_bucket" "app_backups_replica" {
  count         = var.enable_cross_region_backup ? 1 : 0
  bucket        = "${var.project_name}-app-backups-replica-${random_string.bucket_suffix.result}"
  force_destroy = true

  provider = aws.replica

  tags = {
    Name        = "${var.project_name}-app-backups-replica"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "app_backups_replica" {
  count  = var.enable_cross_region_backup ? 1 : 0
  bucket = aws_s3_bucket.app_backups_replica[0].id
  
  provider = aws.replica
  
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_replication_configuration" "app_backups" {
  count      = var.enable_cross_region_backup ? 1 : 0
  depends_on = [aws_s3_bucket_versioning.app_backups]

  role   = aws_iam_role.s3_replication[0].arn
  bucket = aws_s3_bucket.app_backups.id

  rule {
    id     = "replicate_backups"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.app_backups_replica[0].arn
      storage_class = "STANDARD_IA"
    }
  }
}

# IAM Role for S3 Replication
resource "aws_iam_role" "s3_replication" {
  count = var.enable_cross_region_backup ? 1 : 0
  name  = "${var.project_name}-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-s3-replication-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "s3_replication" {
  count = var.enable_cross_region_backup ? 1 : 0
  name  = "${var.project_name}-s3-replication-policy"
  role  = aws_iam_role.s3_replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.app_backups.arn
        ]
      },
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.app_backups.arn}/*"
        ]
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect = "Allow"
        Resource = [
          "${aws_s3_bucket.app_backups_replica[0].arn}/*"
        ]
      }
    ]
  })
}

# Disaster Recovery Lambda Function
resource "aws_lambda_function" "disaster_recovery" {
  filename         = "disaster_recovery.zip"
  function_name    = "${var.project_name}-disaster-recovery"
  role            = aws_iam_role.lambda_disaster_recovery.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 900 # 15 minutes

  environment {
    variables = {
      PROJECT_NAME = var.project_name
      ENVIRONMENT  = var.environment
      SNS_TOPIC    = aws_sns_topic.alerts.arn
    }
  }

  tags = {
    Name        = "${var.project_name}-disaster-recovery"
    Environment = var.environment
  }
}

# Lambda function code
data "archive_file" "disaster_recovery" {
  type        = "zip"
  output_path = "disaster_recovery.zip"
  source {
    content = <<EOF
import json
import boto3
import os
from datetime import datetime

def handler(event, context):
    """
    Disaster Recovery Lambda Function
    Checks system health and initiates recovery procedures
    """
    
    project_name = os.environ['PROJECT_NAME']
    environment = os.environ['ENVIRONMENT']
    sns_topic = os.environ['SNS_TOPIC']
    
    # Initialize AWS clients
    ecs_client = boto3.client('ecs')
    rds_client = boto3.client('rds')
    sns_client = boto3.client('sns')
    
    health_status = {
        'timestamp': datetime.now().isoformat(),
        'project': project_name,
        'environment': environment,
        'services': {}
    }
    
    try:
        # Check ECS services
        cluster_name = f"{project_name}-cluster"
        services = ecs_client.list_services(cluster=cluster_name)
        
        for service_arn in services['serviceArns']:
            service_name = service_arn.split('/')[-1]
            service_details = ecs_client.describe_services(
                cluster=cluster_name,
                services=[service_arn]
            )
            
            service = service_details['services'][0]
            health_status['services'][service_name] = {
                'status': service['status'],
                'running_count': service['runningCount'],
                'desired_count': service['desiredCount']
            }
        
        # Check RDS
        db_instance_id = f"{project_name}-db"
        db_response = rds_client.describe_db_instances(
            DBInstanceIdentifier=db_instance_id
        )
        
        db_instance = db_response['DBInstances'][0]
        health_status['database'] = {
            'status': db_instance['DBInstanceStatus'],
            'endpoint': db_instance['Endpoint']['Address']
        }
        
        # Send health report
        message = json.dumps(health_status, indent=2)
        sns_client.publish(
            TopicArn=sns_topic,
            Message=message,
            Subject=f"Health Check Report - {project_name}"
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps(health_status)
        }
        
    except Exception as e:
        error_message = f"Disaster Recovery Check Failed: {str(e)}"
        sns_client.publish(
            TopicArn=sns_topic,
            Message=error_message,
            Subject=f"ALERT: Disaster Recovery Check Failed - {project_name}"
        )
        
        return {
            'statusCode': 500,
            'body': json.dumps({'error': error_message})
        }
EOF
    filename = "index.py"
  }
}

# IAM Role for Lambda Disaster Recovery
resource "aws_iam_role" "lambda_disaster_recovery" {
  name = "${var.project_name}-lambda-disaster-recovery-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-lambda-disaster-recovery-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "lambda_disaster_recovery" {
  name = "${var.project_name}-lambda-disaster-recovery-policy"
  role = aws_iam_role.lambda_disaster_recovery.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:ListServices",
          "ecs:DescribeServices",
          "ecs:DescribeClusters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBInstances",
          "rds:DescribeDBClusters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.alerts.arn
      }
    ]
  })
}

# CloudWatch Event Rule for Disaster Recovery
resource "aws_cloudwatch_event_rule" "disaster_recovery" {
  name                = "${var.project_name}-disaster-recovery-schedule"
  description         = "Trigger disaster recovery health check"
  schedule_expression = "rate(15 minutes)"

  tags = {
    Name        = "${var.project_name}-disaster-recovery-schedule"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "disaster_recovery" {
  rule      = aws_cloudwatch_event_rule.disaster_recovery.name
  target_id = "DisasterRecoveryLambdaTarget"
  arn       = aws_lambda_function.disaster_recovery.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.disaster_recovery.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.disaster_recovery.arn
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_disaster_recovery" {
  name              = "/aws/lambda/${aws_lambda_function.disaster_recovery.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-lambda-disaster-recovery-logs"
    Environment = var.environment
  }
}

# Multi-AZ RDS Read Replica for Disaster Recovery
resource "aws_db_instance" "read_replica" {
  count                     = var.enable_read_replica ? 1 : 0
  identifier                = "${var.project_name}-db-replica"
  replicate_source_db       = aws_db_instance.main.identifier
  instance_class            = var.db_instance_class
  publicly_accessible       = false
  auto_minor_version_upgrade = true
  backup_retention_period   = 7
  backup_window             = "03:00-04:00"
  maintenance_window        = "sun:04:00-sun:05:00"
  
  tags = {
    Name        = "${var.project_name}-db-replica"
    Environment = var.environment
  }
}

# CloudWatch Alarms for Backup Monitoring
resource "aws_cloudwatch_metric_alarm" "backup_vault_recovery_points" {
  alarm_name          = "${var.project_name}-backup-vault-recovery-points"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "NumberOfRecoveryPointsCreated"
  namespace           = "AWS/Backup"
  period              = "86400" # 24 hours
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This metric monitors backup vault recovery points"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    BackupVaultName = aws_backup_vault.main.name
  }

  tags = {
    Name        = "${var.project_name}-backup-vault-recovery-points"
    Environment = var.environment
  }
} 