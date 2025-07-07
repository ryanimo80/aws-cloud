# ECS Services and Service Discovery for Django Microservices

#######################
# Service Discovery
#######################

# Create a private DNS namespace for service discovery
resource "aws_service_discovery_private_dns_namespace" "main" {
  name        = "${var.project_name}.local"
  description = "Service discovery namespace for ${var.project_name}"
  vpc         = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-service-discovery"
  })
}

# Service discovery services
resource "aws_service_discovery_service" "microservices" {
  for_each = toset(var.microservices)

  name = each.value

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.main.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_grace_period_seconds = 30

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-${each.value}-discovery"
    Service = each.value
  })
}

#######################
# ECS Service for API Gateway
#######################

resource "aws_ecs_service" "api_gateway" {
  name            = "${var.project_name}-api-gateway"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api_gateway.arn
  desired_count   = var.ecs_service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.microservices["api-gateway"].arn
    container_name   = "api-gateway"
    container_port   = 8000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.microservices["api-gateway"].arn
  }

  depends_on = [
    aws_lb_listener.main,
    aws_iam_role_policy_attachment.ecs_execution_role_policy
  ]

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-api-gateway-service"
    Service = "api-gateway"
  })
}

#######################
# ECS Service for User Service
#######################

resource "aws_ecs_service" "user_service" {
  name            = "${var.project_name}-user-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.user_service.arn
  desired_count   = var.ecs_service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.microservices["user-service"].arn
    container_name   = "user-service"
    container_port   = 8001
  }

  service_registries {
    registry_arn = aws_service_discovery_service.microservices["user-service"].arn
  }

  depends_on = [
    aws_lb_listener.main,
    aws_iam_role_policy_attachment.ecs_execution_role_policy
  ]

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-user-service-service"
    Service = "user-service"
  })
}

#######################
# ECS Service for Product Service
#######################

resource "aws_ecs_service" "product_service" {
  name            = "${var.project_name}-product-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.product_service.arn
  desired_count   = var.ecs_service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.microservices["product-service"].arn
    container_name   = "product-service"
    container_port   = 8002
  }

  service_registries {
    registry_arn = aws_service_discovery_service.microservices["product-service"].arn
  }

  depends_on = [
    aws_lb_listener.main,
    aws_iam_role_policy_attachment.ecs_execution_role_policy
  ]

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-product-service-service"
    Service = "product-service"
  })
}

#######################
# ECS Service for Order Service
#######################

resource "aws_ecs_service" "order_service" {
  name            = "${var.project_name}-order-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.order_service.arn
  desired_count   = var.ecs_service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.microservices["order-service"].arn
    container_name   = "order-service"
    container_port   = 8003
  }

  service_registries {
    registry_arn = aws_service_discovery_service.microservices["order-service"].arn
  }

  depends_on = [
    aws_lb_listener.main,
    aws_iam_role_policy_attachment.ecs_execution_role_policy
  ]

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-order-service-service"
    Service = "order-service"
  })
}

#######################
# ECS Service for Notification Service
#######################

resource "aws_ecs_service" "notification_service" {
  name            = "${var.project_name}-notification-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.notification_service.arn
  desired_count   = var.ecs_service_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.microservices["notification-service"].arn
    container_name   = "notification-service"
    container_port   = 8004
  }

  service_registries {
    registry_arn = aws_service_discovery_service.microservices["notification-service"].arn
  }

  depends_on = [
    aws_lb_listener.main,
    aws_iam_role_policy_attachment.ecs_execution_role_policy
  ]

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-notification-service-service"
    Service = "notification-service"
  })
}

#######################
# Auto Scaling
#######################

# Auto Scaling Target for API Gateway
resource "aws_appautoscaling_target" "api_gateway" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api_gateway.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-api-gateway-scaling-target"
    Service = "api-gateway"
  })
}

# Auto Scaling Policy for API Gateway
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
    target_value = 70.0
  }
}

# Auto Scaling Target for User Service
resource "aws_appautoscaling_target" "user_service" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.user_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-user-service-scaling-target"
    Service = "user-service"
  })
}

# Auto Scaling Policy for User Service
resource "aws_appautoscaling_policy" "user_service_up" {
  name               = "${var.project_name}-user-service-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.user_service.resource_id
  scalable_dimension = aws_appautoscaling_target.user_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.user_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Auto Scaling Target for Product Service
resource "aws_appautoscaling_target" "product_service" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.product_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-product-service-scaling-target"
    Service = "product-service"
  })
}

# Auto Scaling Policy for Product Service
resource "aws_appautoscaling_policy" "product_service_up" {
  name               = "${var.project_name}-product-service-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.product_service.resource_id
  scalable_dimension = aws_appautoscaling_target.product_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.product_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Auto Scaling Target for Order Service
resource "aws_appautoscaling_target" "order_service" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.order_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-order-service-scaling-target"
    Service = "order-service"
  })
}

# Auto Scaling Policy for Order Service
resource "aws_appautoscaling_policy" "order_service_up" {
  name               = "${var.project_name}-order-service-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.order_service.resource_id
  scalable_dimension = aws_appautoscaling_target.order_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.order_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# Auto Scaling Target for Notification Service
resource "aws_appautoscaling_target" "notification_service" {
  max_capacity       = 10
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.notification_service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = merge(local.common_tags, {
    Name    = "${var.project_name}-notification-service-scaling-target"
    Service = "notification-service"
  })
}

# Auto Scaling Policy for Notification Service
resource "aws_appautoscaling_policy" "notification_service_up" {
  name               = "${var.project_name}-notification-service-scale-up"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.notification_service.resource_id
  scalable_dimension = aws_appautoscaling_target.notification_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.notification_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = 70.0
  }
} 