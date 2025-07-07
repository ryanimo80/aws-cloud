# Load Testing Infrastructure
# This file contains load testing infrastructure for performance testing

# ECS Task Definition for Load Testing
resource "aws_ecs_task_definition" "load_test" {
  count                    = var.enable_load_testing ? 1 : 0
  family                   = "${var.project_name}-load-test"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "load-test"
      image = "locustio/locust:latest"
      
      portMappings = [
        {
          containerPort = 8089
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "LOCUST_HOST"
          value = "http://${aws_lb.main.dns_name}"
        },
        {
          name  = "LOCUST_USERS"
          value = tostring(var.load_test_target_rps * 10)
        },
        {
          name  = "LOCUST_SPAWN_RATE"
          value = "10"
        },
        {
          name  = "LOCUST_RUN_TIME"
          value = "${var.load_test_duration}m"
        }
      ]

      command = [
        "locust",
        "-f", "/mnt/locust/locustfile.py",
        "--host", "http://${aws_lb.main.dns_name}",
        "--headless",
        "--users", tostring(var.load_test_target_rps * 10),
        "--spawn-rate", "10",
        "--run-time", "${var.load_test_duration}m",
        "--csv=/tmp/results"
      ]

      mountPoints = [
        {
          sourceVolume  = "locust-scripts"
          containerPath = "/mnt/locust"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.load_test[0].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "load-test"
        }
      }
    }
  ])

  volume {
    name = "locust-scripts"
    
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.load_test[0].id
      root_directory = "/"
    }
  }

  tags = {
    Name        = "${var.project_name}-load-test-task"
    Environment = var.environment
  }
}

# EFS for Load Test Scripts
resource "aws_efs_file_system" "load_test" {
  count                           = var.enable_load_testing ? 1 : 0
  creation_token                  = "${var.project_name}-load-test-efs"
  performance_mode               = "generalPurpose"
  encrypted                      = true
  
  tags = {
    Name        = "${var.project_name}-load-test-efs"
    Environment = var.environment
  }
}

resource "aws_efs_mount_target" "load_test" {
  count           = var.enable_load_testing ? length(aws_subnet.private) : 0
  file_system_id  = aws_efs_file_system.load_test[0].id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs[0].id]
}

# Security Group for EFS
resource "aws_security_group" "efs" {
  count       = var.enable_load_testing ? 1 : 0
  name        = "${var.project_name}-efs-sg"
  description = "Security group for EFS"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-efs-sg"
    Environment = var.environment
  }
}

# CloudWatch Log Group for Load Testing
resource "aws_cloudwatch_log_group" "load_test" {
  count             = var.enable_load_testing ? 1 : 0
  name              = "/aws/ecs/${var.project_name}-load-test"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-load-test-logs"
    Environment = var.environment
  }
}

# Load Test Results S3 Bucket
resource "aws_s3_bucket" "load_test_results" {
  count  = var.enable_load_testing ? 1 : 0
  bucket = "${var.project_name}-load-test-results"

  tags = {
    Name        = "${var.project_name}-load-test-results"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "load_test_results" {
  count  = var.enable_load_testing ? 1 : 0
  bucket = aws_s3_bucket.load_test_results[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "load_test_results" {
  count  = var.enable_load_testing ? 1 : 0
  bucket = aws_s3_bucket.load_test_results[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lambda Function for Load Test Orchestration
resource "aws_lambda_function" "load_test_orchestrator" {
  count            = var.enable_load_testing ? 1 : 0
  filename         = "load_test_orchestrator.zip"
  function_name    = "${var.project_name}-load-test-orchestrator"
  role            = aws_iam_role.lambda_load_test[0].arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 900

  environment {
    variables = {
      PROJECT_NAME    = var.project_name
      ENVIRONMENT     = var.environment
      CLUSTER_NAME    = aws_ecs_cluster.main.name
      TASK_DEFINITION = aws_ecs_task_definition.load_test[0].arn
      SUBNET_IDS      = join(",", aws_subnet.private[*].id)
      SECURITY_GROUP  = aws_security_group.ecs_tasks.id
      S3_BUCKET       = aws_s3_bucket.load_test_results[0].bucket
      SNS_TOPIC       = aws_sns_topic.alerts.arn
      ALB_DNS         = aws_lb.main.dns_name
    }
  }

  tags = {
    Name        = "${var.project_name}-load-test-orchestrator"
    Environment = var.environment
  }
}

# Load Test Orchestrator Lambda Code
data "archive_file" "load_test_orchestrator" {
  count       = var.enable_load_testing ? 1 : 0
  type        = "zip"
  output_path = "load_test_orchestrator.zip"
  source {
    content = <<EOF
import json
import boto3
import os
import time
from datetime import datetime

def handler(event, context):
    """
    Load Test Orchestrator Lambda Function
    Manages load testing execution and results collection
    """
    
    project_name = os.environ['PROJECT_NAME']
    environment = os.environ['ENVIRONMENT']
    cluster_name = os.environ['CLUSTER_NAME']
    task_definition = os.environ['TASK_DEFINITION']
    subnet_ids = os.environ['SUBNET_IDS'].split(',')
    security_group = os.environ['SECURITY_GROUP']
    s3_bucket = os.environ['S3_BUCKET']
    sns_topic = os.environ['SNS_TOPIC']
    alb_dns = os.environ['ALB_DNS']
    
    # Initialize AWS clients
    ecs = boto3.client('ecs')
    s3 = boto3.client('s3')
    sns = boto3.client('sns')
    cloudwatch = boto3.client('cloudwatch')
    
    try:
        action = event.get('action', 'run')
        
        if action == 'run':
            # Start load test
            response = ecs.run_task(
                cluster=cluster_name,
                taskDefinition=task_definition,
                launchType='FARGATE',
                networkConfiguration={
                    'awsvpcConfiguration': {
                        'subnets': subnet_ids,
                        'securityGroups': [security_group],
                        'assignPublicIp': 'DISABLED'
                    }
                },
                overrides={
                    'containerOverrides': [
                        {
                            'name': 'load-test',
                            'environment': [
                                {
                                    'name': 'TEST_RUN_ID',
                                    'value': datetime.now().strftime('%Y%m%d-%H%M%S')
                                }
                            ]
                        }
                    ]
                }
            )
            
            task_arn = response['tasks'][0]['taskArn']
            
            # Send notification
            sns.publish(
                TopicArn=sns_topic,
                Message=f"Load test started for {project_name}\\nTask ARN: {task_arn}\\nTarget: {alb_dns}",
                Subject=f"Load Test Started - {project_name}"
            )
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'Load test started',
                    'task_arn': task_arn,
                    'target': alb_dns
                })
            }
            
        elif action == 'status':
            # Check load test status
            tasks = ecs.list_tasks(
                cluster=cluster_name,
                family=f"{project_name}-load-test"
            )
            
            if not tasks['taskArns']:
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'status': 'no_running_tests',
                        'message': 'No load tests currently running'
                    })
                }
            
            # Get task details
            task_details = ecs.describe_tasks(
                cluster=cluster_name,
                tasks=tasks['taskArns']
            )
            
            status_info = []
            for task in task_details['tasks']:
                status_info.append({
                    'task_arn': task['taskArn'],
                    'last_status': task['lastStatus'],
                    'desired_status': task['desiredStatus'],
                    'created_at': task['createdAt'].isoformat(),
                    'cpu': task['cpu'],
                    'memory': task['memory']
                })
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'status': 'running',
                    'tasks': status_info
                })
            }
            
        elif action == 'results':
            # Get load test results
            try:
                objects = s3.list_objects_v2(
                    Bucket=s3_bucket,
                    Prefix='load-test-results/'
                )
                
                results = []
                for obj in objects.get('Contents', []):
                    results.append({
                        'key': obj['Key'],
                        'last_modified': obj['LastModified'].isoformat(),
                        'size': obj['Size']
                    })
                
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'results': results,
                        'count': len(results)
                    })
                }
                
            except Exception as e:
                return {
                    'statusCode': 404,
                    'body': json.dumps({
                        'error': 'No results found',
                        'message': str(e)
                    })
                }
        
        elif action == 'stop':
            # Stop running load tests
            tasks = ecs.list_tasks(
                cluster=cluster_name,
                family=f"{project_name}-load-test"
            )
            
            stopped_tasks = []
            for task_arn in tasks['taskArns']:
                ecs.stop_task(
                    cluster=cluster_name,
                    task=task_arn,
                    reason='Stopped by orchestrator'
                )
                stopped_tasks.append(task_arn)
            
            sns.publish(
                TopicArn=sns_topic,
                Message=f"Load test stopped for {project_name}\\nStopped tasks: {len(stopped_tasks)}",
                Subject=f"Load Test Stopped - {project_name}"
            )
            
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': f'Stopped {len(stopped_tasks)} load test tasks',
                    'stopped_tasks': stopped_tasks
                })
            }
        
        else:
            return {
                'statusCode': 400,
                'body': json.dumps({
                    'error': 'Invalid action',
                    'valid_actions': ['run', 'status', 'results', 'stop']
                })
            }
            
    except Exception as e:
        error_message = f"Load Test Orchestrator Failed: {str(e)}"
        
        sns.publish(
            TopicArn=sns_topic,
            Message=error_message,
            Subject=f"ALERT: Load Test Failed - {project_name}"
        )
        
        return {
            'statusCode': 500,
            'body': json.dumps({'error': error_message})
        }
EOF
    filename = "index.py"
  }
}

# IAM Role for Load Test Orchestrator Lambda
resource "aws_iam_role" "lambda_load_test" {
  count = var.enable_load_testing ? 1 : 0
  name  = "${var.project_name}-lambda-load-test-role"

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
    Name        = "${var.project_name}-lambda-load-test-role"
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "lambda_load_test" {
  count = var.enable_load_testing ? 1 : 0
  name  = "${var.project_name}-lambda-load-test-policy"
  role  = aws_iam_role.lambda_load_test[0].id

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
          "ecs:RunTask",
          "ecs:StopTask",
          "ecs:DescribeTasks",
          "ecs:ListTasks"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.load_test_results[0].arn,
          "${aws_s3_bucket.load_test_results[0].arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.alerts.arn
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_task_execution_role.arn,
          aws_iam_role.ecs_task_role.arn
        ]
      }
    ]
  })
}

# API Gateway for Load Test Control
resource "aws_api_gateway_rest_api" "load_test_api" {
  count       = var.enable_load_testing ? 1 : 0
  name        = "${var.project_name}-load-test-api"
  description = "API for controlling load tests"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "${var.project_name}-load-test-api"
    Environment = var.environment
  }
}

resource "aws_api_gateway_resource" "load_test" {
  count       = var.enable_load_testing ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.load_test_api[0].id
  parent_id   = aws_api_gateway_rest_api.load_test_api[0].root_resource_id
  path_part   = "loadtest"
}

resource "aws_api_gateway_method" "load_test_post" {
  count         = var.enable_load_testing ? 1 : 0
  rest_api_id   = aws_api_gateway_rest_api.load_test_api[0].id
  resource_id   = aws_api_gateway_resource.load_test[0].id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "load_test_lambda" {
  count       = var.enable_load_testing ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.load_test_api[0].id
  resource_id = aws_api_gateway_resource.load_test[0].id
  http_method = aws_api_gateway_method.load_test_post[0].http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.load_test_orchestrator[0].invoke_arn
}

resource "aws_api_gateway_deployment" "load_test_api" {
  count       = var.enable_load_testing ? 1 : 0
  depends_on  = [aws_api_gateway_integration.load_test_lambda[0]]
  rest_api_id = aws_api_gateway_rest_api.load_test_api[0].id
  stage_name  = "prod"

  tags = {
    Name        = "${var.project_name}-load-test-api-deployment"
    Environment = var.environment
  }
}

resource "aws_lambda_permission" "allow_api_gateway" {
  count         = var.enable_load_testing ? 1 : 0
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.load_test_orchestrator[0].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.load_test_api[0].execution_arn}/*/*"
}

# Load Test Dashboard
resource "aws_cloudwatch_dashboard" "load_test" {
  count          = var.enable_load_testing ? 1 : 0
  dashboard_name = "${var.project_name}-load-test-dashboard"

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
            ["AWS/ECS", "CPUUtilization", "ServiceName", "${var.project_name}-load-test", "ClusterName", aws_ecs_cluster.main.name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Load Test Task Performance"
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
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix],
            [".", "TargetResponseTime", ".", "."],
            [".", "HTTPCode_Target_2XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Application Performance Under Load"
          period  = 300
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-load-test-dashboard"
    Environment = var.environment
  }
} 