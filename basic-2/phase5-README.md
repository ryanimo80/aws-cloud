# Phase 5: ECS Task Definitions và Services

## 🎯 Mục Tiêu
Tạo ECS Task Definitions và Services để deploy các Django microservices lên AWS ECS Fargate với load balancing, service discovery, và auto-scaling.

## 📋 Các Bước Thực Hiện

### 1. ECS Task Definitions (`terraform/ecs-tasks.tf`)

#### Task Definition Components
- ✅ **CPU và Memory**: Resource allocation per service
- ✅ **Container Definitions**: Service-specific configurations
- ✅ **Environment Variables**: Configuration management
- ✅ **Logging**: CloudWatch log integration
- ✅ **Health Checks**: Container health monitoring
- ✅ **Network Mode**: awsvpc networking

#### API Gateway Task Definition
```hcl
resource "aws_ecs_task_definition" "api_gateway" {
  family                   = "${var.project_name}-api-gateway"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.api_gateway_cpu
  memory                   = var.api_gateway_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "api-gateway"
      image = "${var.ecr_registry}/django-microservices/api-gateway:${var.image_tag}"
      
      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DJANGO_SETTINGS_MODULE"
          value = "config.settings.production"
        },
        {
          name  = "DATABASE_URL"
          value = "postgresql://${var.db_username}:${var.db_password}@${aws_db_instance.main.endpoint}/${var.db_name}"
        },
        {
          name  = "REDIS_URL"
          value = "redis://${aws_elasticache_cluster.main.cache_nodes[0].address}:6379/0"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api_gateway.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8000/health/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])
}
```

#### User Service Task Definition
- ✅ **Resource Allocation**: 512 CPU, 1024 MB memory
- ✅ **Port Configuration**: Container port 8001
- ✅ **Environment Variables**: Database và Redis URLs
- ✅ **Health Checks**: Custom health endpoint

#### Product Service Task Definition
- ✅ **Resource Allocation**: 1024 CPU, 2048 MB memory
- ✅ **Port Configuration**: Container port 8002
- ✅ **Image Processing**: Additional memory for image handling
- ✅ **Search Integration**: Elasticsearch environment variables

#### Order Service Task Definition
- ✅ **Resource Allocation**: 1024 CPU, 2048 MB memory
- ✅ **Port Configuration**: Container port 8003
- ✅ **Payment Integration**: Payment service environment variables
- ✅ **Queue Configuration**: Celery worker configuration

#### Notification Service Task Definition
- ✅ **Resource Allocation**: 512 CPU, 1024 MB memory
- ✅ **Port Configuration**: Container port 8004
- ✅ **Email Configuration**: SMTP settings
- ✅ **SMS Configuration**: SMS provider settings

### 2. ECS Services (`terraform/ecs-services.tf`)

#### Service Configuration
- ✅ **Service Discovery**: AWS Cloud Map integration
- ✅ **Load Balancing**: ALB target group association
- ✅ **Health Checks**: ELB health check configuration
- ✅ **Deployment Configuration**: Rolling updates
- ✅ **Network Configuration**: VPC và Security Groups

#### API Gateway Service
```hcl
resource "aws_ecs_service" "api_gateway" {
  name            = "${var.project_name}-api-gateway"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api_gateway.arn
  desired_count   = var.api_gateway_count
  launch_type     = "FARGATE"
  
  platform_version = "LATEST"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api_gateway.arn
    container_name   = "api-gateway"
    container_port   = 8000
  }

  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = 100
  }

  depends_on = [
    aws_lb_listener.main,
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy
  ]

  tags = {
    Name        = "${var.project_name}-api-gateway-service"
    Environment = var.environment
  }
}
```

#### Service Auto-scaling
```hcl
resource "aws_appautoscaling_target" "api_gateway" {
  max_capacity       = var.api_gateway_max_count
  min_capacity       = var.api_gateway_min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api_gateway.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "api_gateway_up" {
  name               = "${var.project_name}-api-gateway-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api_gateway.resource_id
  scalable_dimension = aws_appautoscaling_target.api_gateway.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api_gateway.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.autoscaling_target_cpu
  }
}
```

### 3. Load Balancer Target Groups (`terraform/alb-targets.tf`)

#### Target Group Configuration
- ✅ **Health Check Path**: Service-specific health endpoints
- ✅ **Health Check Protocol**: HTTP/HTTPS
- ✅ **Health Check Intervals**: Optimized timing
- ✅ **Deregistration Delay**: Connection draining
- ✅ **Stickiness**: Session affinity configuration

```hcl
resource "aws_lb_target_group" "api_gateway" {
  name     = "${var.project_name}-api-gateway-tg"
  port     = 8000
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
    Name        = "${var.project_name}-api-gateway-tg"
    Environment = var.environment
  }
}
```

### 4. Service Discovery (`terraform/service-discovery.tf`)

#### AWS Cloud Map Configuration
- ✅ **Private DNS Namespace**: Internal service discovery
- ✅ **Service Registration**: Automatic service registration
- ✅ **Health Checks**: Service health monitoring
- ✅ **DNS Records**: A và SRV records

```hcl
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.project_name}.local"
  description = "Private DNS namespace for ${var.project_name}"
  vpc         = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-dns-namespace"
    Environment = var.environment
  }
}

resource "aws_service_discovery_service" "api_gateway" {
  name = "api-gateway"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_grace_period_seconds = 30
}
```

### 5. Application Load Balancer Rules (`terraform/alb-rules.tf`)

#### Routing Rules
- ✅ **Path-based Routing**: Service-specific paths
- ✅ **Host-based Routing**: Domain-based routing
- ✅ **Priority Configuration**: Rule precedence
- ✅ **Default Actions**: Fallback behavior

```hcl
resource "aws_lb_listener_rule" "api_gateway" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_gateway.arn
  }

  condition {
    path_pattern {
      values = ["/api/gateway/*", "/api/auth/*"]
    }
  }
}

resource "aws_lb_listener_rule" "user_service" {
  listener_arn = aws_lb_listener.main.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.user_service.arn
  }

  condition {
    path_pattern {
      values = ["/api/users/*"]
    }
  }
}
```

### 6. Environment Configuration

#### Terraform Variables (`terraform/variables.tf`)
```hcl
# ECS Service Configuration
variable "api_gateway_cpu" {
  description = "CPU units for API Gateway"
  type        = number
  default     = 512
}

variable "api_gateway_memory" {
  description = "Memory for API Gateway"
  type        = number
  default     = 1024
}

variable "api_gateway_count" {
  description = "Number of API Gateway instances"
  type        = number
  default     = 2
}

variable "api_gateway_min_count" {
  description = "Minimum number of API Gateway instances"
  type        = number
  default     = 1
}

variable "api_gateway_max_count" {
  description = "Maximum number of API Gateway instances"
  type        = number
  default     = 10
}
```

#### Environment Specific Configuration
```hcl
# Development Environment
api_gateway_cpu    = 256
api_gateway_memory = 512
api_gateway_count  = 1

# Staging Environment
api_gateway_cpu    = 512
api_gateway_memory = 1024
api_gateway_count  = 2

# Production Environment
api_gateway_cpu    = 1024
api_gateway_memory = 2048
api_gateway_count  = 3
```

### 7. Monitoring và Logging

#### CloudWatch Log Groups
```hcl
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/ecs/${var.project_name}-api-gateway"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-api-gateway-logs"
    Environment = var.environment
  }
}
```

#### CloudWatch Metrics
- ✅ **Service Metrics**: CPU, Memory, Network utilization
- ✅ **Task Metrics**: Running task count
- ✅ **Load Balancer Metrics**: Request count, response time
- ✅ **Custom Metrics**: Application-specific metrics

## 🔧 Deployment Strategy

### Rolling Deployment
```hcl
deployment_configuration {
  maximum_percent         = 200
  minimum_healthy_percent = 100
  
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}
```

### Blue/Green Deployment
```hcl
deployment_configuration {
  deployment_controller {
    type = "CODE_DEPLOY"
  }
}
```

### Canary Deployment
```hcl
# Using AWS CodeDeploy for canary deployments
resource "aws_codedeploy_application" "microservices" {
  compute_platform = "ECS"
  name             = "${var.project_name}-app"
}
```

## 📊 Kết Quả Đạt Được

✅ **ECS Task Definitions** - Complete task configurations for all services
✅ **ECS Services** - Running services with load balancing
✅ **Auto-scaling** - CPU-based scaling policies
✅ **Service Discovery** - Internal service communication
✅ **Load Balancing** - ALB với health checks
✅ **Health Monitoring** - Container và service health checks
✅ **Logging** - Centralized CloudWatch logging
✅ **Security** - IAM roles và security groups

## 🔍 Service Status

### ECS Cluster Status
```bash
# Check cluster status
aws ecs describe-clusters --clusters django-microservices-cluster

# List services
aws ecs list-services --cluster django-microservices-cluster

# Check service status
aws ecs describe-services --cluster django-microservices-cluster --services api-gateway user-service product-service order-service notification-service
```

### Load Balancer Health
```bash
# Check target group health
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/api-gateway-tg/50dc6c495c0c9188

# Check ALB status
aws elbv2 describe-load-balancers --load-balancer-arns arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/django-microservices-alb/50dc6c495c0c9188
```

## 🚨 Common Issues và Solutions

### 1. Service Startup Issues
```bash
# Check task logs
aws logs get-log-events --log-group-name /ecs/django-microservices-api-gateway --log-stream-name ecs/api-gateway/task-id

# Check service events
aws ecs describe-services --cluster django-microservices-cluster --services api-gateway --query 'services[0].events'
```

### 2. Health Check Failures
```bash
# Check target group health
aws elbv2 describe-target-health --target-group-arn target-group-arn

# Test health endpoint directly
curl -f http://container-ip:8000/health/
```

### 3. Auto-scaling Issues
```bash
# Check scaling activities
aws application-autoscaling describe-scaling-activities --service-namespace ecs --resource-id service/cluster-name/service-name

# Check scaling policies
aws application-autoscaling describe-scaling-policies --service-namespace ecs --resource-id service/cluster-name/service-name
```

## 💰 Cost Analysis

### Resource Allocation
```
API Gateway:    512 CPU, 1024 MB = ~$15/month
User Service:   512 CPU, 1024 MB = ~$15/month
Product Service: 1024 CPU, 2048 MB = ~$30/month
Order Service:  1024 CPU, 2048 MB = ~$30/month
Notification:   512 CPU, 1024 MB = ~$15/month

Total ECS Costs: ~$105/month
ALB Costs: ~$16/month
CloudWatch Logs: ~$5/month

Total: ~$126/month
```

## 📝 Files Created

### ECS Configuration
- `terraform/ecs-tasks.tf` - Task definitions
- `terraform/ecs-services.tf` - ECS services
- `terraform/alb-targets.tf` - Target groups
- `terraform/alb-rules.tf` - Load balancer rules
- `terraform/service-discovery.tf` - Service discovery

### Deployment Scripts
- `scripts/deploy-services.sh` - Service deployment
- `scripts/update-services.sh` - Service updates
- `scripts/scale-services.sh` - Manual scaling

### Monitoring
- CloudWatch log groups for each service
- CloudWatch metrics và alarms
- Service health checks

## 🚀 Chuẩn Bị Cho Phase 6

✅ **ECS Services Running** - All microservices deployed
✅ **Load Balancing** - ALB routing traffic
✅ **Auto-scaling** - Responsive scaling policies
✅ **Service Discovery** - Internal communication
✅ **Health Monitoring** - Service health tracking
✅ **Logging** - Centralized log collection
✅ **Ready for Advanced Features** - Foundation for monitoring và security

---

**Phase 5 Status**: ✅ **COMPLETED**
**Duration**: ~4 hours  
**Next Phase**: Phase 6 - Monitoring và Security 