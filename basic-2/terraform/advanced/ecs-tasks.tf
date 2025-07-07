# ECS Task Definitions for Django Microservices

# Data source for ECR repository URLs
data "aws_ecr_repository" "microservices" {
  for_each = toset(var.microservices)
  name     = "${var.project_name}-${each.value}"
}

#######################
# Task Definition for API Gateway
#######################

resource "aws_ecs_task_definition" "api_gateway" {
  family                   = "${var.project_name}-api-gateway"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "api-gateway"
      image = "${data.aws_ecr_repository.microservices["api-gateway"].repository_url}:latest"
      
      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DEBUG"
          value = "0"
        },
        {
          name  = "DATABASE_URL"
          value = "postgresql://${aws_db_instance.main.username}:${aws_db_instance.main.password}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
        },
        {
          name  = "REDIS_URL"
          value = "redis://${aws_elasticache_cluster.main.cache_nodes[0].address}:${aws_elasticache_cluster.main.cache_nodes[0].port}/0"
        },
        {
          name  = "USER_SERVICE_URL"
          value = "http://user-service.${var.project_name}.local:8001"
        },
        {
          name  = "PRODUCT_SERVICE_URL"
          value = "http://product-service.${var.project_name}.local:8002"
        },
        {
          name  = "ORDER_SERVICE_URL"
          value = "http://order-service.${var.project_name}.local:8003"
        },
        {
          name  = "NOTIFICATION_SERVICE_URL"
          value = "http://notification-service.${var.project_name}.local:8004"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.microservices["api-gateway"].name
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

      essential = true
    }
  ])

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-api-gateway-task"
    Service = "api-gateway"
  })
}

#######################
# Task Definition for User Service
#######################

resource "aws_ecs_task_definition" "user_service" {
  family                   = "${var.project_name}-user-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "user-service"
      image = "${data.aws_ecr_repository.microservices["user-service"].repository_url}:latest"
      
      portMappings = [
        {
          containerPort = 8001
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DEBUG"
          value = "0"
        },
        {
          name  = "DATABASE_URL"
          value = "postgresql://${aws_db_instance.main.username}:${aws_db_instance.main.password}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
        },
        {
          name  = "REDIS_URL"
          value = "redis://${aws_elasticache_cluster.main.cache_nodes[0].address}:${aws_elasticache_cluster.main.cache_nodes[0].port}/1"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.microservices["user-service"].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8001/health/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      essential = true
    }
  ])

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-user-service-task"
    Service = "user-service"
  })
}

#######################
# Task Definition for Product Service
#######################

resource "aws_ecs_task_definition" "product_service" {
  family                   = "${var.project_name}-product-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "product-service"
      image = "${data.aws_ecr_repository.microservices["product-service"].repository_url}:latest"
      
      portMappings = [
        {
          containerPort = 8002
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DEBUG"
          value = "0"
        },
        {
          name  = "DATABASE_URL"
          value = "postgresql://${aws_db_instance.main.username}:${aws_db_instance.main.password}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
        },
        {
          name  = "REDIS_URL"
          value = "redis://${aws_elasticache_cluster.main.cache_nodes[0].address}:${aws_elasticache_cluster.main.cache_nodes[0].port}/2"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.microservices["product-service"].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8002/health/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      essential = true
    }
  ])

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-product-service-task"
    Service = "product-service"
  })
}

#######################
# Task Definition for Order Service
#######################

resource "aws_ecs_task_definition" "order_service" {
  family                   = "${var.project_name}-order-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "order-service"
      image = "${data.aws_ecr_repository.microservices["order-service"].repository_url}:latest"
      
      portMappings = [
        {
          containerPort = 8003
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DEBUG"
          value = "0"
        },
        {
          name  = "DATABASE_URL"
          value = "postgresql://${aws_db_instance.main.username}:${aws_db_instance.main.password}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
        },
        {
          name  = "REDIS_URL"
          value = "redis://${aws_elasticache_cluster.main.cache_nodes[0].address}:${aws_elasticache_cluster.main.cache_nodes[0].port}/3"
        },
        {
          name  = "USER_SERVICE_URL"
          value = "http://user-service.${var.project_name}.local:8001"
        },
        {
          name  = "PRODUCT_SERVICE_URL"
          value = "http://product-service.${var.project_name}.local:8002"
        },
        {
          name  = "NOTIFICATION_SERVICE_URL"
          value = "http://notification-service.${var.project_name}.local:8004"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.microservices["order-service"].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8003/health/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      essential = true
    }
  ])

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-order-service-task"
    Service = "order-service"
  })
}

#######################
# Task Definition for Notification Service
#######################

resource "aws_ecs_task_definition" "notification_service" {
  family                   = "${var.project_name}-notification-service"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.ecs_task_cpu
  memory                   = var.ecs_task_memory
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn           = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "notification-service"
      image = "${data.aws_ecr_repository.microservices["notification-service"].repository_url}:latest"
      
      portMappings = [
        {
          containerPort = 8004
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DEBUG"
          value = "0"
        },
        {
          name  = "DATABASE_URL"
          value = "postgresql://${aws_db_instance.main.username}:${aws_db_instance.main.password}@${aws_db_instance.main.endpoint}/${aws_db_instance.main.db_name}"
        },
        {
          name  = "REDIS_URL"
          value = "redis://${aws_elasticache_cluster.main.cache_nodes[0].address}:${aws_elasticache_cluster.main.cache_nodes[0].port}/4"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.microservices["notification-service"].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:8004/health/ || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }

      essential = true
    }
  ])

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-notification-service-task"
    Service = "notification-service"
  })
} 