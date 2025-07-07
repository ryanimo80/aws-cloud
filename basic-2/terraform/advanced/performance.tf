# Performance Optimization Configuration
# This file contains performance optimization features for the microservices

# CloudFront Distribution for static content and API acceleration
resource "aws_cloudfront_distribution" "main" {
  count               = var.enable_performance_mode ? 1 : 0
  origin {
    domain_name = aws_lb.main.dns_name
    origin_id   = "ALB-${var.project_name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.project_name} CloudFront Distribution"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "ALB-${var.project_name}"

    forwarded_values {
      query_string = true
      headers      = ["Host", "Origin", "Authorization", "Content-Type"]

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  # API endpoints cache behavior
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "ALB-${var.project_name}"

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }

    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "https-only"
  }

  # Static content cache behavior
  ordered_cache_behavior {
    path_pattern     = "/static/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "ALB-${var.project_name}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 86400
    default_ttl            = 2592000
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${var.project_name}-cloudfront"
    Environment = var.environment
  }
}

# ElastiCache Redis Cluster for improved caching
resource "aws_elasticache_replication_group" "main" {
  count                      = var.enable_performance_mode ? 1 : 0
  replication_group_id       = "${var.project_name}-redis-cluster"
  description                = "Redis cluster for ${var.project_name}"
  
  node_type                  = var.redis_node_type
  port                       = 6379
  parameter_group_name       = "default.redis7.cluster.on"
  
  num_cache_clusters         = 2
  automatic_failover_enabled = true
  multi_az_enabled          = true
  
  subnet_group_name = aws_elasticache_subnet_group.main.name
  security_group_ids = [aws_security_group.redis.id]
  
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  
  maintenance_window = "sun:05:00-sun:06:00"
  snapshot_retention_limit = 5
  snapshot_window = "03:00-05:00"
  
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow_log[0].name
    destination_type = "cloudwatch-logs"
    log_format       = "text"
    log_type         = "slow-log"
  }

  tags = {
    Name        = "${var.project_name}-redis-cluster"
    Environment = var.environment
  }
}

# CloudWatch Log Group for Redis slow logs
resource "aws_cloudwatch_log_group" "redis_slow_log" {
  count             = var.enable_performance_mode ? 1 : 0
  name              = "/aws/elasticache/redis/${var.project_name}-slow-log"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-redis-slow-log"
    Environment = var.environment
  }
}

# Application Load Balancer optimization
resource "aws_lb_target_group" "optimized" {
  count       = var.enable_performance_mode ? length(var.services) : 0
  name        = "${var.project_name}-${var.services[count.index]}-opt"
  port        = lookup(var.microservice_ports, var.services[count.index], 8000)
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health/"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  # Performance optimizations
  deregistration_delay = var.connection_draining_timeout
  
  stickiness {
    enabled = false
    type    = "lb_cookie"
  }

  tags = {
    Name        = "${var.project_name}-${var.services[count.index]}-optimized-tg"
    Environment = var.environment
    Service     = var.services[count.index]
  }
}

# Enhanced RDS Performance Insights
resource "aws_rds_cluster_parameter_group" "performance" {
  count       = var.enable_performance_mode ? 1 : 0
  family      = "postgres14"
  name        = "${var.project_name}-performance-params"
  description = "Performance optimized parameter group"

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
    value = "1000" # Log queries taking more than 1 second
  }

  parameter {
    name  = "effective_cache_size"
    value = "262144" # 1GB in 8KB pages
  }

  parameter {
    name  = "random_page_cost"
    value = "1.1" # SSD optimization
  }

  tags = {
    Name        = "${var.project_name}-performance-params"
    Environment = var.environment
  }
}

# Performance monitoring Lambda function
resource "aws_lambda_function" "performance_monitor" {
  count            = var.enable_performance_mode ? 1 : 0
  filename         = "performance_monitor.zip"
  function_name    = "${var.project_name}-performance-monitor"
  role            = aws_iam_role.lambda_performance_monitor[0].arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      PROJECT_NAME = var.project_name
      ENVIRONMENT  = var.environment
      SNS_TOPIC    = aws_sns_topic.alerts.arn
    }
  }

  tags = {
    Name        = "${var.project_name}-performance-monitor"
    Environment = var.environment
  }
}

# Performance monitoring Lambda code
data "archive_file" "performance_monitor" {
  count       = var.enable_performance_mode ? 1 : 0
  type        = "zip"
  output_path = "performance_monitor.zip"
  source {
    content = <<EOF
import json
import boto3
import os
from datetime import datetime, timedelta

def handler(event, context):
    """
    Performance Monitor Lambda Function
    Analyzes performance metrics and provides recommendations
    """
    
    project_name = os.environ['PROJECT_NAME']
    environment = os.environ['ENVIRONMENT']
    sns_topic = os.environ['SNS_TOPIC']
    
    # Initialize AWS clients
    cloudwatch = boto3.client('cloudwatch')
    ecs = boto3.client('ecs')
    sns = boto3.client('sns')
    
    performance_report = {
        'timestamp': datetime.now().isoformat(),
        'project': project_name,
        'environment': environment,
        'metrics': {},
        'recommendations': []
    }
    
    try:
        # Get ECS performance metrics
        end_time = datetime.now()
        start_time = end_time - timedelta(hours=1)
        
        services = ['api-gateway', 'user-service', 'product-service', 'order-service', 'notification-service']
        
        for service in services:
            # Get CPU utilization
            cpu_response = cloudwatch.get_metric_statistics(
                Namespace='AWS/ECS',
                MetricName='CPUUtilization',
                Dimensions=[
                    {'Name': 'ServiceName', 'Value': f"{project_name}-{service}"},
                    {'Name': 'ClusterName', 'Value': f"{project_name}-cluster"}
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['Average', 'Maximum']
            )
            
            # Get Memory utilization
            memory_response = cloudwatch.get_metric_statistics(
                Namespace='AWS/ECS',
                MetricName='MemoryUtilization',
                Dimensions=[
                    {'Name': 'ServiceName', 'Value': f"{project_name}-{service}"},
                    {'Name': 'ClusterName', 'Value': f"{project_name}-cluster"}
                ],
                StartTime=start_time,
                EndTime=end_time,
                Period=300,
                Statistics=['Average', 'Maximum']
            )
            
            # Calculate average metrics
            avg_cpu = 0
            max_cpu = 0
            avg_memory = 0
            max_memory = 0
            
            if cpu_response['Datapoints']:
                avg_cpu = sum(dp['Average'] for dp in cpu_response['Datapoints']) / len(cpu_response['Datapoints'])
                max_cpu = max(dp['Maximum'] for dp in cpu_response['Datapoints'])
            
            if memory_response['Datapoints']:
                avg_memory = sum(dp['Average'] for dp in memory_response['Datapoints']) / len(memory_response['Datapoints'])
                max_memory = max(dp['Maximum'] for dp in memory_response['Datapoints'])
            
            performance_report['metrics'][service] = {
                'avg_cpu': round(avg_cpu, 2),
                'max_cpu': round(max_cpu, 2),
                'avg_memory': round(avg_memory, 2),
                'max_memory': round(max_memory, 2)
            }
            
            # Generate recommendations
            if avg_cpu > 80:
                performance_report['recommendations'].append(
                    f"🔴 {service}: High CPU usage ({avg_cpu:.1f}%) - Consider scaling up or optimizing code"
                )
            elif avg_cpu > 60:
                performance_report['recommendations'].append(
                    f"🟡 {service}: Moderate CPU usage ({avg_cpu:.1f}%) - Monitor closely"
                )
            
            if avg_memory > 80:
                performance_report['recommendations'].append(
                    f"🔴 {service}: High memory usage ({avg_memory:.1f}%) - Consider increasing memory or optimizing"
                )
            elif avg_memory > 60:
                performance_report['recommendations'].append(
                    f"🟡 {service}: Moderate memory usage ({avg_memory:.1f}%) - Monitor for memory leaks"
                )
            
            # Check for low utilization (potential cost optimization)
            if avg_cpu < 20 and avg_memory < 30:
                performance_report['recommendations'].append(
                    f"💰 {service}: Low resource usage - Consider downsizing for cost optimization"
                )
        
        # Get ALB metrics
        alb_response = cloudwatch.get_metric_statistics(
            Namespace='AWS/ApplicationELB',
            MetricName='TargetResponseTime',
            Dimensions=[
                {'Name': 'LoadBalancer', 'Value': f"app/{project_name}-alb"}
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=300,
            Statistics=['Average', 'Maximum']
        )
        
        if alb_response['Datapoints']:
            avg_response_time = sum(dp['Average'] for dp in alb_response['Datapoints']) / len(alb_response['Datapoints'])
            max_response_time = max(dp['Maximum'] for dp in alb_response['Datapoints'])
            
            performance_report['metrics']['alb'] = {
                'avg_response_time': round(avg_response_time, 3),
                'max_response_time': round(max_response_time, 3)
            }
            
            if avg_response_time > 2.0:
                performance_report['recommendations'].append(
                    f"🔴 ALB: High response time ({avg_response_time:.3f}s) - Investigate application performance"
                )
            elif avg_response_time > 1.0:
                performance_report['recommendations'].append(
                    f"🟡 ALB: Moderate response time ({avg_response_time:.3f}s) - Consider optimizations"
                )
        
        # Add general recommendations
        if not performance_report['recommendations']:
            performance_report['recommendations'].append("✅ All services performing within normal parameters")
        
        # Send performance report
        message = json.dumps(performance_report, indent=2)
        sns.publish(
            TopicArn=sns_topic,
            Message=message,
            Subject=f"Performance Report - {project_name}"
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps(performance_report)
        }
        
    except Exception as e:
        error_message = f"Performance Monitor Failed: {str(e)}"
        sns.publish(
            TopicArn=sns_topic,
            Message=error_message,
            Subject=f"ALERT: Performance Monitor Failed - {project_name}"
        )
        
        return {
            'statusCode': 500,
            'body': json.dumps({'error': error_message})
        }
EOF
    filename = "index.py"
  }
}

# IAM Role for Performance Monitor Lambda
resource "aws_iam_role" "lambda_performance_monitor" {
  count = var.enable_performance_mode ? 1 : 0
  name  = "${var.project_name}-lambda-performance-monitor-role"

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
    Name        = "${var.project_name}-lambda-performance-monitor-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "lambda_performance_monitor" {
  count = var.enable_performance_mode ? 1 : 0
  name  = "${var.project_name}-lambda-performance-monitor-policy"
  role  = aws_iam_role.lambda_performance_monitor[0].id

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
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeServices",
          "ecs:DescribeClusters",
          "ecs:ListServices"
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

# CloudWatch Event Rule for Performance Monitor
resource "aws_cloudwatch_event_rule" "performance_monitor" {
  count               = var.enable_performance_mode ? 1 : 0
  name                = "${var.project_name}-performance-monitor-schedule"
  description         = "Trigger performance monitoring"
  schedule_expression = "rate(30 minutes)"

  tags = {
    Name        = "${var.project_name}-performance-monitor-schedule"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "performance_monitor" {
  count     = var.enable_performance_mode ? 1 : 0
  rule      = aws_cloudwatch_event_rule.performance_monitor[0].name
  target_id = "PerformanceMonitorLambdaTarget"
  arn       = aws_lambda_function.performance_monitor[0].arn
}

resource "aws_lambda_permission" "allow_cloudwatch_performance" {
  count         = var.enable_performance_mode ? 1 : 0
  statement_id  = "AllowExecutionFromCloudWatchPerformance"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.performance_monitor[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.performance_monitor[0].arn
}

# Performance optimization CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "performance_optimization" {
  count          = var.enable_performance_mode ? 1 : 0
  dashboard_name = "${var.project_name}-performance-optimization"

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
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix],
            [".", "RequestCount", ".", "."],
            [".", "HTTPCode_Target_2XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ALB Performance Metrics"
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
          metrics = var.enable_performance_mode ? [
            ["AWS/CloudFront", "Requests", "DistributionId", aws_cloudfront_distribution.main[0].id],
            [".", "BytesDownloaded", ".", "."],
            [".", "OriginLatency", ".", "."]
          ] : []
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "CloudFront Performance"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 24
        height = 6

        properties = {
          metrics = [
            for service in var.services : [
              "AWS/ECS", "CPUUtilization", "ServiceName", "${var.project_name}-${service}", "ClusterName", aws_ecs_cluster.main.name
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ECS Service CPU Performance"
          period  = 300
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-performance-optimization-dashboard"
    Environment = var.environment
  }
} 