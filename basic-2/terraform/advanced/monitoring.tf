# CloudWatch Monitoring Infrastructure
# This file contains CloudWatch logs, metrics, alarms, and dashboards

# CloudWatch Log Groups for each service
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/ecs/${var.project_name}-api-gateway"
  retention_in_days = var.log_retention_days
  
  tags = {
    Name        = "${var.project_name}-api-gateway-logs"
    Environment = var.environment
    Service     = "api-gateway"
  }
}

resource "aws_cloudwatch_log_group" "user_service" {
  name              = "/ecs/${var.project_name}-user-service"
  retention_in_days = var.log_retention_days
  
  tags = {
    Name        = "${var.project_name}-user-service-logs"
    Environment = var.environment
    Service     = "user-service"
  }
}

resource "aws_cloudwatch_log_group" "product_service" {
  name              = "/ecs/${var.project_name}-product-service"
  retention_in_days = var.log_retention_days
  
  tags = {
    Name        = "${var.project_name}-product-service-logs"
    Environment = var.environment
    Service     = "product-service"
  }
}

resource "aws_cloudwatch_log_group" "order_service" {
  name              = "/ecs/${var.project_name}-order-service"
  retention_in_days = var.log_retention_days
  
  tags = {
    Name        = "${var.project_name}-order-service-logs"
    Environment = var.environment
    Service     = "order-service"
  }
}

resource "aws_cloudwatch_log_group" "notification_service" {
  name              = "/ecs/${var.project_name}-notification-service"
  retention_in_days = var.log_retention_days
  
  tags = {
    Name        = "${var.project_name}-notification-service-logs"
    Environment = var.environment
    Service     = "notification-service"
  }
}

# CloudWatch Log Group for ALB
resource "aws_cloudwatch_log_group" "alb" {
  name              = "/aws/application-loadbalancer/${var.project_name}"
  retention_in_days = var.log_retention_days
  
  tags = {
    Name        = "${var.project_name}-alb-logs"
    Environment = var.environment
    Service     = "load-balancer"
  }
}

# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
  
  tags = {
    Name        = "${var.project_name}-alerts"
    Environment = var.environment
  }
}

resource "aws_sns_topic_subscription" "email_alerts" {
  count     = length(var.alert_email_addresses)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email_addresses[count.index]
}

# CloudWatch Alarms for ALB
resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  alarm_name          = "${var.project_name}-alb-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors ALB target response time"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-alb-response-time-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.project_name}-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors unhealthy ALB targets"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-alb-unhealthy-hosts-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project_name}-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors ALB 5XX errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-alb-5xx-errors-alarm"
    Environment = var.environment
  }
}

# CloudWatch Alarms for ECS Services
resource "aws_cloudwatch_metric_alarm" "ecs_cpu_utilization" {
  count               = length(var.services)
  alarm_name          = "${var.project_name}-${var.services[count.index]}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS CPU utilization for ${var.services[count.index]}"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = "${var.project_name}-${var.services[count.index]}"
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = {
    Name        = "${var.project_name}-${var.services[count.index]}-cpu-alarm"
    Environment = var.environment
    Service     = var.services[count.index]
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_utilization" {
  count               = length(var.services)
  alarm_name          = "${var.project_name}-${var.services[count.index]}-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS memory utilization for ${var.services[count.index]}"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = "${var.project_name}-${var.services[count.index]}"
    ClusterName = aws_ecs_cluster.main.name
  }

  tags = {
    Name        = "${var.project_name}-${var.services[count.index]}-memory-alarm"
    Environment = var.environment
    Service     = var.services[count.index]
  }
}

# CloudWatch Alarms for RDS
resource "aws_cloudwatch_metric_alarm" "rds_cpu_utilization" {
  alarm_name          = "${var.project_name}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = {
    Name        = "${var.project_name}-rds-cpu-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_database_connections" {
  alarm_name          = "${var.project_name}-rds-high-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "This metric monitors RDS database connections"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = {
    Name        = "${var.project_name}-rds-connections-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage_space" {
  alarm_name          = "${var.project_name}-rds-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "2000000000" # 2GB in bytes
  alarm_description   = "This metric monitors RDS free storage space"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = {
    Name        = "${var.project_name}-rds-storage-alarm"
    Environment = var.environment
  }
}

# CloudWatch Alarms for ElastiCache
resource "aws_cloudwatch_metric_alarm" "elasticache_cpu_utilization" {
  alarm_name          = "${var.project_name}-redis-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ElastiCache CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    CacheClusterId = aws_elasticache_cluster.main.cluster_id
  }

  tags = {
    Name        = "${var.project_name}-redis-cpu-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_metric_alarm" "elasticache_memory_utilization" {
  alarm_name          = "${var.project_name}-redis-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ElastiCache memory utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    CacheClusterId = aws_elasticache_cluster.main.cluster_id
  }

  tags = {
    Name        = "${var.project_name}-redis-memory-alarm"
    Environment = var.environment
  }
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix],
            [".", "TargetResponseTime", ".", "."],
            [".", "HTTPCode_Target_2XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Application Load Balancer Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            for service in var.services : 
            ["AWS/ECS", "CPUUtilization", "ServiceName", "${var.project_name}-${service}", "ClusterName", aws_ecs_cluster.main.name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ECS Service CPU Utilization"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            for service in var.services : 
            ["AWS/ECS", "MemoryUtilization", "ServiceName", "${var.project_name}-${service}", "ClusterName", aws_ecs_cluster.main.name]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ECS Service Memory Utilization"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.id],
            [".", "DatabaseConnections", ".", "."],
            [".", "FreeStorageSpace", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "RDS Database Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ElastiCache", "CPUUtilization", "CacheClusterId", aws_elasticache_cluster.main.cluster_id],
            [".", "DatabaseMemoryUsagePercentage", ".", "."],
            [".", "CurrConnections", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ElastiCache Redis Metrics"
          period  = 300
        }
      },
      {
        type   = "log"
        x      = 12
        y      = 12
        width  = 12
        height = 6

        properties = {
          query   = "SOURCE '/ecs/${var.project_name}-api-gateway' | fields @timestamp, @message | sort @timestamp desc | limit 100"
          region  = var.aws_region
          title   = "Recent Application Logs"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-dashboard"
    Environment = var.environment
  }
}

# CloudWatch Composite Alarm for Service Health
resource "aws_cloudwatch_composite_alarm" "service_health" {
  alarm_name        = "${var.project_name}-service-health"
  alarm_description = "Composite alarm for overall service health"
  
  alarm_rule = join(" OR ", [
    for service in var.services :
    "ALARM(${aws_cloudwatch_metric_alarm.ecs_cpu_utilization[index(var.services, service)].alarm_name})"
  ])
  
  actions_enabled = true
  alarm_actions   = [aws_sns_topic.alerts.arn]
  ok_actions      = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project_name}-service-health-alarm"
    Environment = var.environment
  }
}

# CloudWatch Log Insights Queries
resource "aws_cloudwatch_query_definition" "error_logs" {
  name = "${var.project_name}-error-logs"

  log_group_names = [
    aws_cloudwatch_log_group.api_gateway.name,
    aws_cloudwatch_log_group.user_service.name,
    aws_cloudwatch_log_group.product_service.name,
    aws_cloudwatch_log_group.order_service.name,
    aws_cloudwatch_log_group.notification_service.name
  ]

  query_string = <<EOF
fields @timestamp, @message, @logStream
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
EOF
}

resource "aws_cloudwatch_query_definition" "performance_logs" {
  name = "${var.project_name}-performance-logs"

  log_group_names = [
    aws_cloudwatch_log_group.api_gateway.name,
    aws_cloudwatch_log_group.user_service.name,
    aws_cloudwatch_log_group.product_service.name,
    aws_cloudwatch_log_group.order_service.name,
    aws_cloudwatch_log_group.notification_service.name
  ]

  query_string = <<EOF
fields @timestamp, @message, @logStream
| filter @message like /response_time/
| stats avg(response_time) by bin(5m)
| sort @timestamp desc
EOF
} 