# Variables for Core Infrastructure Module
# Phase 2: Core Infrastructure

# Project Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "django-microservices"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Number of availability zones"
  type        = number
  default     = 2
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway for cost optimization"
  type        = bool
  default     = true
}

# Database Configuration
variable "database_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "database_allocated_storage" {
  description = "RDS allocated storage"
  type        = number
  default     = 20
}

variable "database_max_allocated_storage" {
  description = "RDS max allocated storage"
  type        = number
  default     = 100
}

variable "database_backup_retention_period" {
  description = "RDS backup retention period"
  type        = number
  default     = 7
}

variable "database_multi_az" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
}

variable "database_deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "create_initial_snapshot" {
  description = "Create initial snapshot"
  type        = bool
  default     = false
}

# Redis Configuration
variable "redis_node_type" {
  description = "Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
}

variable "redis_parameter_group_name" {
  description = "Redis parameter group name"
  type        = string
  default     = "default.redis7"
}

variable "redis_port" {
  description = "Redis port"
  type        = number
  default     = 6379
}

# ECS Configuration
variable "ecs_task_cpu" {
  description = "ECS task CPU"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "ECS task memory"
  type        = number
  default     = 512
}

variable "ecs_service_desired_count" {
  description = "ECS service desired count"
  type        = number
  default     = 1
}

# Microservices Configuration
variable "microservices" {
  description = "Set of microservices"
  type        = set(string)
  default = [
    "api-gateway",
    "user-service",
    "product-service",
    "order-service",
    "notification-service"
  ]
}

variable "microservice_ports" {
  description = "Port mapping for microservices"
  type        = map(number)
  default = {
    "api-gateway"        = 8000
    "user-service"       = 8001
    "product-service"    = 8002
    "order-service"      = 8003
    "notification-service" = 8004
  }
}

# Security Configuration
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false
}

# Logging Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

# Tags
variable "additional_tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
} 