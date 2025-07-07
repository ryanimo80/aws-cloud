# VPC Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

# Subnet Outputs
output "public_subnet_ids" {
  description = "List of IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "List of IDs of the database subnets"
  value       = aws_subnet.database[*].id
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = local.azs
}

# Security Group Outputs
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "ecs_tasks_security_group_id" {
  description = "ID of the ECS tasks security group"
  value       = aws_security_group.ecs_tasks.id
}

output "database_security_group_id" {
  description = "ID of the database security group"
  value       = aws_security_group.database.id
}

output "redis_security_group_id" {
  description = "ID of the Redis security group"
  value       = aws_security_group.redis.id
}

# Database Outputs
output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "database_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "database_name" {
  description = "RDS instance database name"
  value       = aws_db_instance.main.db_name
}

output "database_username" {
  description = "RDS instance master username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

# Redis Outputs
output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = aws_elasticache_cluster.main.cache_nodes[0].address
  sensitive   = true
}

output "redis_port" {
  description = "Redis cluster port"
  value       = aws_elasticache_cluster.main.cache_nodes[0].port
}

# ECS Outputs
output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

# IAM Role Outputs
output "ecs_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task_role.arn
}

# Load Balancer Outputs
output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "alb_listener_arn" {
  description = "ARN of the ALB listener"
  value       = aws_lb_listener.main.arn
}

# Target Group Outputs
output "target_group_arns" {
  description = "ARNs of the target groups"
  value = {
    for service, tg in aws_lb_target_group.microservices : service => tg.arn
  }
}

output "target_group_names" {
  description = "Names of the target groups"
  value = {
    for service, tg in aws_lb_target_group.microservices : service => tg.name
  }
}

# ECR Outputs
output "ecr_repository_urls" {
  description = "URLs of the ECR repositories"
  value = {
    for service, repo in aws_ecr_repository.microservices : service => repo.repository_url
  }
}

output "ecr_repository_arns" {
  description = "ARNs of the ECR repositories"
  value = {
    for service, repo in aws_ecr_repository.microservices : service => repo.arn
  }
}

# CloudWatch Log Group Outputs
output "cloudwatch_log_group_name" {
  description = "Name of the main CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs.name
}

output "microservice_log_groups" {
  description = "Names of the microservice CloudWatch log groups"
  value = {
    for service, lg in aws_cloudwatch_log_group.microservices : service => lg.name
  }
}

# NAT Gateway Outputs
output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "nat_gateway_public_ips" {
  description = "List of public IPs of the NAT Gateways"
  value       = aws_eip.nat[*].public_ip
}

# Internet Gateway Output
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

# Project Information
output "project_name" {
  description = "Name of the project"
  value       = var.project_name
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

# Cost Optimization Info
output "single_nat_gateway" {
  description = "Whether single NAT Gateway is used"
  value       = var.single_nat_gateway
}

output "database_multi_az" {
  description = "Whether RDS Multi-AZ is enabled"
  value       = var.database_multi_az
}

# Microservices Configuration
output "microservices" {
  description = "List of microservices"
  value       = var.microservices
}

output "microservice_ports" {
  description = "Port mapping for microservices"
  value       = var.microservice_ports
}

# Connection Information for Phase 3
output "database_connection_info" {
  description = "Database connection information for applications"
  value = {
    host     = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
    database = aws_db_instance.main.db_name
    username = aws_db_instance.main.username
  }
  sensitive = true
}

output "redis_connection_info" {
  description = "Redis connection information for applications"
  value = {
    host = aws_elasticache_cluster.main.cache_nodes[0].address
    port = aws_elasticache_cluster.main.cache_nodes[0].port
  }
  sensitive = true
}

# Infrastructure URLs
output "infrastructure_urls" {
  description = "Important infrastructure URLs"
  value = {
    load_balancer = "http://${aws_lb.main.dns_name}"
    api_gateway   = "http://${aws_lb.main.dns_name}"
    users_api     = "http://${aws_lb.main.dns_name}/users"
    products_api  = "http://${aws_lb.main.dns_name}/products"
    orders_api    = "http://${aws_lb.main.dns_name}/orders"
    notifications_api = "http://${aws_lb.main.dns_name}/notifications"
  }
}

# ECS Task Definition Outputs
output "ecs_task_definition_arns" {
  description = "ARNs of ECS task definitions"
  value = {
    api_gateway         = aws_ecs_task_definition.api_gateway.arn
    user_service        = aws_ecs_task_definition.user_service.arn
    product_service     = aws_ecs_task_definition.product_service.arn
    order_service       = aws_ecs_task_definition.order_service.arn
    notification_service = aws_ecs_task_definition.notification_service.arn
  }
}

# ECS Service Outputs
output "ecs_service_arns" {
  description = "ARNs of ECS services"
  value = {
    api_gateway         = aws_ecs_service.api_gateway.id
    user_service        = aws_ecs_service.user_service.id
    product_service     = aws_ecs_service.product_service.id
    order_service       = aws_ecs_service.order_service.id
    notification_service = aws_ecs_service.notification_service.id
  }
}

# Service Discovery Outputs
output "service_discovery_namespace" {
  description = "Service discovery namespace"
  value = {
    id   = aws_service_discovery_private_dns_namespace.main.id
    name = aws_service_discovery_private_dns_namespace.main.name
  }
}

output "service_discovery_services" {
  description = "Service discovery service ARNs"
  value = {
    for service, discovery in aws_service_discovery_service.microservices : service => discovery.arn
  }
}

# Auto Scaling Outputs
output "autoscaling_targets" {
  description = "Auto scaling target ARNs"
  value = {
    api_gateway         = aws_appautoscaling_target.api_gateway.arn
    user_service        = aws_appautoscaling_target.user_service.arn
    product_service     = aws_appautoscaling_target.product_service.arn
    order_service       = aws_appautoscaling_target.order_service.arn
    notification_service = aws_appautoscaling_target.notification_service.arn
  }
}

# Deployment Information
output "deployment_info" {
  description = "Deployment information for scripts"
  value = {
    cluster_name = aws_ecs_cluster.main.name
    services = [
      for service in var.microservices : "${var.project_name}-${service}"
    ]
    load_balancer_dns = aws_lb.main.dns_name
    ecr_registry = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  }
} 