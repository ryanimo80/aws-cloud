# Cost Optimization Configuration
# This file contains cost optimization features for AWS resources

# Spot Fleet Configuration for Cost Optimization
resource "aws_spot_fleet_request" "main" {
  iam_fleet_role      = aws_iam_role.spot_fleet_role.arn
  allocation_strategy = "lowestPrice"
  target_capacity     = 2
  spot_price          = "0.05"
  valid_until         = "2025-12-31T23:59:59Z"

  launch_specification {
    image_id          = "ami-0c02fb55956c7d316" # Amazon Linux 2
    instance_type     = "t3.medium"
    key_name          = var.key_pair_name
    subnet_id         = aws_subnet.private[0].id
    security_groups   = [aws_security_group.ecs_tasks.id]
    
    user_data = base64encode(templatefile("${path.module}/user_data.sh", {
      cluster_name = aws_ecs_cluster.main.name
    }))

    iam_instance_profile {
      name = aws_iam_instance_profile.ecs_instance_profile.name
    }
  }

  launch_specification {
    image_id          = "ami-0c02fb55956c7d316" # Amazon Linux 2
    instance_type     = "t3.small"
    key_name          = var.key_pair_name
    subnet_id         = aws_subnet.private[1].id
    security_groups   = [aws_security_group.ecs_tasks.id]
    
    user_data = base64encode(templatefile("${path.module}/user_data.sh", {
      cluster_name = aws_ecs_cluster.main.name
    }))

    iam_instance_profile {
      name = aws_iam_instance_profile.ecs_instance_profile.name
    }
  }

  tags = {
    Name        = "${var.project_name}-spot-fleet"
    Environment = var.environment
  }
}

# IAM Role for Spot Fleet
resource "aws_iam_role" "spot_fleet_role" {
  name = "${var.project_name}-spot-fleet-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "spotfleet.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-spot-fleet-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "spot_fleet_policy" {
  role       = aws_iam_role.spot_fleet_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2SpotFleetTaggingRole"
}

# ECS Instance Profile for Spot Instances
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "${var.project_name}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance_role.name

  tags = {
    Name        = "${var.project_name}-ecs-instance-profile"
    Environment = var.environment
  }
}

resource "aws_iam_role" "ecs_instance_role" {
  name = "${var.project_name}-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-ecs-instance-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

# User Data Script for ECS Instances
resource "local_file" "user_data_script" {
  filename = "${path.module}/user_data.sh"
  content  = <<-EOF
#!/bin/bash
echo ECS_CLUSTER=${aws_ecs_cluster.main.name} >> /etc/ecs/ecs.config
yum update -y
yum install -y amazon-cloudwatch-agent
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent
EOF
}

# Lambda Function for Cost Optimization
resource "aws_lambda_function" "cost_optimizer" {
  filename         = "cost_optimizer.zip"
  function_name    = "${var.project_name}-cost-optimizer"
  role            = aws_iam_role.lambda_cost_optimizer.arn
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
    Name        = "${var.project_name}-cost-optimizer"
    Environment = var.environment
  }
}

# Cost Optimizer Lambda Code
data "archive_file" "cost_optimizer" {
  type        = "zip"
  output_path = "cost_optimizer.zip"
  source {
    content = <<EOF
import json
import boto3
import os
from datetime import datetime, timedelta

def handler(event, context):
    """
    Cost Optimizer Lambda Function
    Analyzes AWS usage and provides cost optimization recommendations
    """
    
    project_name = os.environ['PROJECT_NAME']
    environment = os.environ['ENVIRONMENT']
    sns_topic = os.environ['SNS_TOPIC']
    
    # Initialize AWS clients
    cloudwatch = boto3.client('cloudwatch')
    ecs = boto3.client('ecs')
    rds = boto3.client('rds')
    sns = boto3.client('sns')
    ce = boto3.client('ce')
    
    cost_report = {
        'timestamp': datetime.now().isoformat(),
        'project': project_name,
        'environment': environment,
        'recommendations': [],
        'estimated_savings': 0
    }
    
    try:
        # Get cost data for the last 30 days
        end_date = datetime.now().strftime('%Y-%m-%d')
        start_date = (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d')
        
        cost_response = ce.get_cost_and_usage(
            TimePeriod={
                'Start': start_date,
                'End': end_date
            },
            Granularity='MONTHLY',
            Metrics=['BlendedCost'],
            GroupBy=[
                {
                    'Type': 'DIMENSION',
                    'Key': 'SERVICE'
                }
            ]
        )
        
        # Analyze ECS utilization
        end_time = datetime.now()
        start_time = end_time - timedelta(hours=24)
        
        services = ['api-gateway', 'user-service', 'product-service', 'order-service', 'notification-service']
        
        low_utilization_services = []
        
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
                Period=3600,
                Statistics=['Average']
            )
            
            if cpu_response['Datapoints']:
                avg_cpu = sum(dp['Average'] for dp in cpu_response['Datapoints']) / len(cpu_response['Datapoints'])
                
                if avg_cpu < 10:
                    low_utilization_services.append({
                        'service': service,
                        'avg_cpu': round(avg_cpu, 2),
                        'recommendation': 'Consider downsizing or using spot instances',
                        'estimated_savings': 30  # 30% savings
                    })
        
        # Generate recommendations
        if low_utilization_services:
            for service_info in low_utilization_services:
                cost_report['recommendations'].append(
                    f"💰 {service_info['service']}: Low CPU utilization ({service_info['avg_cpu']}%) - {service_info['recommendation']}"
                )
                cost_report['estimated_savings'] += service_info['estimated_savings']
        
        # RDS utilization check
        rds_response = cloudwatch.get_metric_statistics(
            Namespace='AWS/RDS',
            MetricName='CPUUtilization',
            Dimensions=[
                {'Name': 'DBClusterIdentifier', 'Value': f"{project_name}-cluster"}
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,
            Statistics=['Average']
        )
        
        if rds_response['Datapoints']:
            avg_rds_cpu = sum(dp['Average'] for dp in rds_response['Datapoints']) / len(rds_response['Datapoints'])
            
            if avg_rds_cpu < 20:
                cost_report['recommendations'].append(
                    f"💰 RDS: Low CPU utilization ({avg_rds_cpu:.1f}%) - Consider smaller instance type"
                )
                cost_report['estimated_savings'] += 25
        
        # Check for unused resources
        # ELB without targets
        elb_response = cloudwatch.get_metric_statistics(
            Namespace='AWS/ApplicationELB',
            MetricName='RequestCount',
            Dimensions=[
                {'Name': 'LoadBalancer', 'Value': f"{project_name}-alb"}
            ],
            StartTime=start_time,
            EndTime=end_time,
            Period=3600,
            Statistics=['Sum']
        )
        
        if elb_response['Datapoints']:
            total_requests = sum(dp['Sum'] for dp in elb_response['Datapoints'])
            
            if total_requests < 100:
                cost_report['recommendations'].append(
                    f"💰 ALB: Low request count ({total_requests} requests/day) - Consider using Application Load Balancer only when needed"
                )
                cost_report['estimated_savings'] += 20
        
        # Spot instance recommendations
        cost_report['recommendations'].append(
            "💰 General: Consider using Spot Instances for non-critical workloads (up to 90% savings)"
        )
        
        # Reserved instance recommendations
        cost_report['recommendations'].append(
            "💰 General: Consider Reserved Instances for predictable workloads (up to 75% savings)"
        )
        
        # Storage optimization
        cost_report['recommendations'].append(
            "💰 Storage: Implement S3 lifecycle policies to transition to cheaper storage classes"
        )
        
        # Add general recommendations if no specific ones found
        if not cost_report['recommendations']:
            cost_report['recommendations'].append("✅ All resources are optimally utilized")
        
        # Calculate estimated monthly savings
        if cost_report['estimated_savings'] > 0:
            cost_report['estimated_monthly_savings'] = f"${cost_report['estimated_savings']:.2f} - ${cost_report['estimated_savings'] * 2:.2f}"
        else:
            cost_report['estimated_monthly_savings'] = "No immediate savings identified"
        
        # Send cost optimization report
        message = f"""
Cost Optimization Report - {project_name}
Generated: {cost_report['timestamp']}

Recommendations:
{chr(10).join(cost_report['recommendations'])}

Estimated Monthly Savings: {cost_report['estimated_monthly_savings']}

Tips:
• Monitor usage patterns and adjust capacity accordingly
• Use scheduled scaling for predictable workloads
• Consider multi-AZ deployment only for production
• Implement auto-scaling to handle traffic spikes efficiently
• Use CloudWatch alarms to detect unused resources
        """
        
        sns.publish(
            TopicArn=sns_topic,
            Message=message,
            Subject=f"Cost Optimization Report - {project_name}"
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps(cost_report)
        }
        
    except Exception as e:
        error_message = f"Cost Optimizer Failed: {str(e)}"
        sns.publish(
            TopicArn=sns_topic,
            Message=error_message,
            Subject=f"ALERT: Cost Optimizer Failed - {project_name}"
        )
        
        return {
            'statusCode': 500,
            'body': json.dumps({'error': error_message})
        }
EOF
    filename = "index.py"
  }
}

# IAM Role for Cost Optimizer Lambda
resource "aws_iam_role" "lambda_cost_optimizer" {
  name = "${var.project_name}-lambda-cost-optimizer-role"

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
    Name        = "${var.project_name}-lambda-cost-optimizer-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "lambda_cost_optimizer" {
  name = "${var.project_name}-lambda-cost-optimizer-policy"
  role = aws_iam_role.lambda_cost_optimizer.id

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
          "rds:DescribeDBClusters",
          "rds:DescribeDBInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ce:GetCostAndUsage",
          "ce:GetDimensionValues",
          "ce:GetUsageReport"
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

# CloudWatch Event Rule for Cost Optimization
resource "aws_cloudwatch_event_rule" "cost_optimizer" {
  name                = "${var.project_name}-cost-optimizer-schedule"
  description         = "Trigger cost optimization analysis"
  schedule_expression = "cron(0 9 1 * ? *)" # First day of each month at 9 AM

  tags = {
    Name        = "${var.project_name}-cost-optimizer-schedule"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "cost_optimizer" {
  rule      = aws_cloudwatch_event_rule.cost_optimizer.name
  target_id = "CostOptimizerLambdaTarget"
  arn       = aws_lambda_function.cost_optimizer.arn
}

resource "aws_lambda_permission" "allow_cloudwatch_cost" {
  statement_id  = "AllowExecutionFromCloudWatchCost"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_optimizer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cost_optimizer.arn
}

# S3 Lifecycle Configuration for Cost Optimization
resource "aws_s3_bucket_lifecycle_configuration" "cost_optimization" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id

  rule {
    id     = "cost_optimization"
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
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }

    expiration {
      days = 2555  # 7 years
    }
  }
}

# Cost Anomaly Detection
resource "aws_ce_anomaly_detector" "service_monitor" {
  name = "${var.project_name}-service-anomaly-detector"
  monitor_type = "DIMENSIONAL"

  specification = jsonencode({
    Dimension = "SERVICE"
    MatchOptions = ["EQUALS"]
    Values = ["Amazon Elastic Container Service", "Amazon Relational Database Service"]
  })

  tags = {
    Name        = "${var.project_name}-service-anomaly-detector"
    Environment = var.environment
  }
}

resource "aws_ce_anomaly_subscription" "service_monitor" {
  name      = "${var.project_name}-service-anomaly-subscription"
  frequency = "DAILY"
  
  monitor_arn_list = [
    aws_ce_anomaly_detector.service_monitor.arn
  ]
  
  subscriber {
    type    = "EMAIL"
    address = var.alert_email
  }

  threshold_expression {
    and {
      dimension {
        key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
        values        = ["100"]
        match_options = ["GREATER_THAN_OR_EQUAL"]
      }
    }
  }

  tags = {
    Name        = "${var.project_name}-service-anomaly-subscription"
    Environment = var.environment
  }
}

# Budget for Cost Control
resource "aws_budgets_budget" "project_budget" {
  name         = "${var.project_name}-monthly-budget"
  budget_type  = "COST"
  limit_amount = "100"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  time_period_start = "2024-01-01_00:00"

  cost_filters {
    tag {
      key    = "Project"
      values = [var.project_name]
    }
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.alert_email]
  }

  tags = {
    Name        = "${var.project_name}-monthly-budget"
    Environment = var.environment
  }
} 