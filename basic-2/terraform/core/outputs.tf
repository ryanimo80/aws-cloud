# Core Infrastructure Outputs
# These outputs will be used by advanced module and displayed to user

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  description = "List of availability zones"
  value       = local.azs
}

# Security Group Outputs
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "ecs_security_group_id" {
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

# ECS Outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.main.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution_role.arn
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task_role.arn
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
  description = "RDS database name"
  value       = aws_db_instance.main.db_name
}

output "database_username" {
  description = "RDS database username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

# Redis Outputs
output "redis_endpoint" {
  description = "Redis primary endpoint"
  value       = aws_elasticache_cluster.main.cache_nodes[0].address
  sensitive   = true
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_cluster.main.port
}

# ALB Outputs
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

output "alb_target_group_arns" {
  description = "ARNs of the target groups"
  value       = { for k, v in aws_lb_target_group.microservices : k => v.arn }
}

# SSM Parameter Store Outputs
output "database_password_parameter" {
  description = "SSM parameter name for database password"
  value       = aws_ssm_parameter.db_password.name
}

output "database_url_parameter" {
  description = "SSM parameter name for database URL"
  value       = aws_ssm_parameter.database_url.name
}

# CloudWatch Log Groups
output "log_group_names" {
  description = "Names of CloudWatch log groups"
  value       = { for k, v in aws_cloudwatch_log_group.microservices : k => v.name }
}

# ECR Repository URLs (if created)
output "ecr_repository_urls" {
  description = "URLs of ECR repositories"
  value       = { for k, v in aws_ecr_repository.microservices : k => v.repository_url }
}

# Network Configuration for Advanced Module
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "route_table_ids" {
  description = "IDs of route tables"
  value = {
    public  = aws_route_table.public.id
    private = aws_route_table.private[*].id
  }
} 