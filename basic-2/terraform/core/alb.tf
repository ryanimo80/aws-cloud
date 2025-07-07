# Application Load Balancer Configuration
# Phase 2: Infrastructure Setup

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = var.enable_deletion_protection

  # Access logs
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb-access-logs"
    enabled = true
  }

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
    Project     = var.project_name
  }
}

# S3 Bucket for ALB Access Logs
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${var.project_name}-alb-logs-${random_string.bucket_suffix.result}"
  force_destroy = var.environment != "production"

  tags = {
    Name        = "${var.project_name}-alb-logs"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Random string for bucket suffix
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket public access block
resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket policy for ALB access logs
data "aws_elb_service_account" "main" {}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = data.aws_elb_service_account.main.arn
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/alb-access-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.alb_logs.arn}/alb-access-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.alb_logs.arn
      }
    ]
  })
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# Target Groups for Microservices
resource "aws_lb_target_group" "microservices" {
  for_each = var.microservices

  name     = "${var.project_name}-${each.value}-tg"
  port     = var.microservice_ports[each.value]
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
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

  deregistration_delay = 30

  tags = {
    Name        = "${var.project_name}-${each.value}-tg"
    Environment = var.environment
    Project     = var.project_name
    Service     = each.value
  }
}

# ALB Listener (HTTP)
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.microservices["api-gateway"].arn
  }

  tags = {
    Name        = "${var.project_name}-alb-listener"
    Environment = var.environment
    Project     = var.project_name
  }
}

# ALB Listener Rules for routing
resource "aws_lb_listener_rule" "api_gateway" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.microservices["api-gateway"].arn
  }

  condition {
    path_pattern {
      values = ["/api/gateway/*", "/api/auth/*", "/health", "/"]
    }
  }

  tags = {
    Name        = "${var.project_name}-api-gateway-rule"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_lb_listener_rule" "user_service" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.microservices["user-service"].arn
  }

  condition {
    path_pattern {
      values = ["/api/users/*"]
    }
  }

  tags = {
    Name        = "${var.project_name}-user-service-rule"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_lb_listener_rule" "product_service" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 300

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.microservices["product-service"].arn
  }

  condition {
    path_pattern {
      values = ["/api/products/*", "/api/categories/*"]
    }
  }

  tags = {
    Name        = "${var.project_name}-product-service-rule"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_lb_listener_rule" "order_service" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 400

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.microservices["order-service"].arn
  }

  condition {
    path_pattern {
      values = ["/api/orders/*"]
    }
  }

  tags = {
    Name        = "${var.project_name}-order-service-rule"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_lb_listener_rule" "notification_service" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 500

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.microservices["notification-service"].arn
  }

  condition {
    path_pattern {
      values = ["/api/notifications/*", "/api/templates/*"]
    }
  }

  tags = {
    Name        = "${var.project_name}-notification-service-rule"
    Environment = var.environment
    Project     = var.project_name
  }
}

# CloudWatch Log Group for ALB
resource "aws_cloudwatch_log_group" "alb" {
  name              = "/aws/elasticloadbalancing/${var.project_name}-alb"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-alb-logs"
    Environment = var.environment
    Project     = var.project_name
  }
} 