# ElastiCache Redis Configuration
# Phase 2: Infrastructure Setup

# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-redis-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name        = "${var.project_name}-redis-subnet-group"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ElastiCache Parameter Group for Redis 7.x
resource "aws_elasticache_parameter_group" "main" {
  family = "redis7.x"
  name   = "${var.project_name}-redis-params"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "notify-keyspace-events"
    value = "Ex"
  }

  parameter {
    name  = "slowlog-log-slower-than"
    value = "10000"
  }

  parameter {
    name  = "slowlog-max-len"
    value = "128"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  tags = {
    Name        = "${var.project_name}-redis-params"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Random auth token for Redis
resource "random_password" "redis_auth_token" {
  length  = 32
  special = false
}

# Store Redis auth token in AWS Systems Manager Parameter Store
resource "aws_ssm_parameter" "redis_auth_token" {
  name        = "/${var.project_name}/redis/auth_token"
  description = "Redis auth token for ${var.project_name}"
  type        = "SecureString"
  value       = random_password.redis_auth_token.result

  tags = {
    Name        = "${var.project_name}-redis-auth-token"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ElastiCache Redis Cluster
resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "${var.project_name}-redis"
  description                = "Redis cluster for ${var.project_name}"
  
  node_type                  = var.redis_node_type
  port                       = 6379
  parameter_group_name       = aws_elasticache_parameter_group.main.name
  
  num_cache_clusters         = var.redis_num_cache_nodes
  
  engine_version             = "7.0"
  
  subnet_group_name          = aws_elasticache_subnet_group.main.name
  security_group_ids         = [aws_security_group.redis.id]
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth_token.result
  
  # Multi-AZ with automatic failover
  multi_az_enabled           = false
  automatic_failover_enabled = false
  
  # Backup configuration
  snapshot_retention_limit = 5
  snapshot_window         = "03:00-05:00"
  
  # Maintenance
  maintenance_window = "sun:05:00-sun:06:00"
  
  # CloudWatch Logs
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis.name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  tags = {
    Name        = "${var.project_name}-redis"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudWatch Log Group for Redis
resource "aws_cloudwatch_log_group" "redis" {
  name              = "/aws/elasticache/${var.project_name}-redis"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-redis-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Store Redis endpoint in SSM Parameter Store
resource "aws_ssm_parameter" "redis_endpoint" {
  name        = "/${var.project_name}/redis/endpoint"
  description = "Redis primary endpoint for ${var.project_name}"
  type        = "String"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address

  tags = {
    Name        = "${var.project_name}-redis-endpoint"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Store Redis connection URL in SSM Parameter Store
resource "aws_ssm_parameter" "redis_url" {
  name        = "/${var.project_name}/redis/url"
  description = "Complete Redis URL for ${var.project_name}"
  type        = "SecureString"
  value       = "redis://:${random_password.redis_auth_token.result}@${aws_elasticache_replication_group.main.primary_endpoint_address}:6379/0"

  tags = {
    Name        = "${var.project_name}-redis-url"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudWatch Alarms for Redis
resource "aws_cloudwatch_metric_alarm" "redis_cpu_high" {
  alarm_name          = "${var.project_name}-redis-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors Redis CPU utilization"
  alarm_actions       = [] # Add SNS topic ARN here if needed

  dimensions = {
    CacheClusterId = "${var.project_name}-redis-001"
  }

  tags = {
    Name        = "${var.project_name}-redis-cpu-alarm"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_metric_alarm" "redis_memory_high" {
  alarm_name          = "${var.project_name}-redis-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors Redis memory utilization"
  alarm_actions       = [] # Add SNS topic ARN here if needed

  dimensions = {
    CacheClusterId = "${var.project_name}-redis-001"
  }

  tags = {
    Name        = "${var.project_name}-redis-memory-alarm"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_cloudwatch_metric_alarm" "redis_evictions" {
  alarm_name          = "${var.project_name}-redis-evictions"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Evictions"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors Redis evictions"
  alarm_actions       = [] # Add SNS topic ARN here if needed

  dimensions = {
    CacheClusterId = "${var.project_name}-redis-001"
  }

  tags = {
    Name        = "${var.project_name}-redis-evictions-alarm"
    Environment = var.environment
    Project     = var.project_name
  }
} 