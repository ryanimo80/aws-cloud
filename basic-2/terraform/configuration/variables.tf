# General Configuration
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name of the project - used in resource naming"
  type        = string
  default     = "django-microservices"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

# VPC Configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
  
  validation {
    condition     = var.availability_zones >= 2 && var.availability_zones <= 4
    error_message = "Availability zones must be between 2 and 4."
  }
}

# NAT Gateway Configuration
variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
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
  
  validation {
    condition = contains([
      "db.t3.micro", "db.t3.small", "db.t3.medium",
      "db.t4g.micro", "db.t4g.small", "db.t4g.medium"
    ], var.database_instance_class)
    error_message = "Database instance class must be a valid RDS instance type."
  }
}

variable "database_allocated_storage" {
  description = "Initial allocated storage for RDS instance (GB)"
  type        = number
  default     = 20
  
  validation {
    condition     = var.database_allocated_storage >= 20 && var.database_allocated_storage <= 1000
    error_message = "Database allocated storage must be between 20 and 1000 GB."
  }
}

variable "database_max_allocated_storage" {
  description = "Maximum allocated storage for RDS auto-scaling (GB)"
  type        = number
  default     = 100
}

variable "database_backup_retention_period" {
  description = "Number of days to retain database backups"
  type        = number
  default     = 7
  
  validation {
    condition     = var.database_backup_retention_period >= 0 && var.database_backup_retention_period <= 35
    error_message = "Backup retention period must be between 0 and 35 days."
  }
}

variable "database_multi_az" {
  description = "Enable Multi-AZ deployment for RDS"
  type        = bool
  default     = false  # Cost optimization for dev environment
}

variable "database_deletion_protection" {
  description = "Enable deletion protection for RDS instance"
  type        = bool
  default     = false  # Disabled for testing environments
}

# ElastiCache Configuration
variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
  
  validation {
    condition = contains([
      "cache.t3.micro", "cache.t3.small", "cache.t3.medium",
      "cache.t4g.micro", "cache.t4g.small", "cache.t4g.medium"
    ], var.redis_node_type)
    error_message = "Redis node type must be a valid ElastiCache instance type."
  }
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes in the Redis cluster"
  type        = number
  default     = 1
  
  validation {
    condition     = var.redis_num_cache_nodes >= 1 && var.redis_num_cache_nodes <= 6
    error_message = "Redis cache nodes must be between 1 and 6."
  }
}

variable "redis_parameter_group_name" {
  description = "Name of the parameter group for Redis"
  type        = string
  default     = "default.redis7"
}

# ECS Configuration
variable "ecs_task_cpu" {
  description = "CPU units for ECS tasks (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 256
  
  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.ecs_task_cpu)
    error_message = "ECS task CPU must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "ecs_task_memory" {
  description = "Memory for ECS tasks (MB)"
  type        = number
  default     = 512
  
  validation {
    condition     = var.ecs_task_memory >= 512 && var.ecs_task_memory <= 8192
    error_message = "ECS task memory must be between 512 and 8192 MB."
  }
}

variable "ecs_service_desired_count" {
  description = "Desired number of ECS service instances"
  type        = number
  default     = 1
  
  validation {
    condition     = var.ecs_service_desired_count >= 1 && var.ecs_service_desired_count <= 10
    error_message = "ECS service desired count must be between 1 and 10."
  }
}

# Load Balancer Configuration
variable "enable_deletion_protection" {
  description = "Enable deletion protection for ALB"
  type        = bool
  default     = false  # Disabled for testing environments
}

# CloudWatch Configuration
variable "log_retention_in_days" {
  description = "CloudWatch log retention period in days"
  type        = number
  default     = 7
  
  validation {
    condition = contains([
      1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653
    ], var.log_retention_in_days)
    error_message = "Log retention must be a valid CloudWatch retention period."
  }
}

# Microservices Configuration
variable "microservices" {
  description = "List of microservices to deploy"
  type        = list(string)
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
    "api-gateway"         = 8000
    "user-service"        = 8001
    "product-service"     = 8002
    "order-service"       = 8003
    "notification-service" = 8004
  }
}

# Tags
variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Security Configuration
variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access ALB"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# ECR Configuration
variable "ecr_image_tag_mutability" {
  description = "Image tag mutability setting for ECR repositories"
  type        = string
  default     = "MUTABLE"
  
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.ecr_image_tag_mutability)
    error_message = "ECR image tag mutability must be either MUTABLE or IMMUTABLE."
  }
}

variable "ecr_scan_on_push" {
  description = "Enable image scanning on push to ECR"
  type        = bool
  default     = true
}

# Monitoring Configuration
variable "log_retention_days" {
  description = "Number of days to retain CloudWatch logs"
  type        = number
  default     = 14
  validation {
    condition     = var.log_retention_days >= 1 && var.log_retention_days <= 3653
    error_message = "Log retention days must be between 1 and 3653."
  }
}

variable "alert_email_addresses" {
  description = "List of email addresses to receive alerts"
  type        = list(string)
  default     = []
  validation {
    condition     = length(var.alert_email_addresses) >= 0
    error_message = "Alert email addresses must be a valid list."
  }
}

variable "security_email_addresses" {
  description = "List of email addresses to receive security alerts"
  type        = list(string)
  default     = []
  validation {
    condition     = length(var.security_email_addresses) >= 0
    error_message = "Security email addresses must be a valid list."
  }
}

# Backup Configuration
variable "enable_cross_region_backup" {
  description = "Enable cross-region backup replication"
  type        = bool
  default     = false
}

variable "enable_read_replica" {
  description = "Enable RDS read replica for disaster recovery"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
  validation {
    condition     = var.backup_retention_period >= 1 && var.backup_retention_period <= 35
    error_message = "Backup retention period must be between 1 and 35 days."
  }
}

# Security Configuration
variable "enable_waf" {
  description = "Enable WAF (Web Application Firewall)"
  type        = bool
  default     = true
}

variable "waf_rate_limit" {
  description = "WAF rate limit per IP address"
  type        = number
  default     = 2000
  validation {
    condition     = var.waf_rate_limit >= 100 && var.waf_rate_limit <= 20000000
    error_message = "WAF rate limit must be between 100 and 20000000."
  }
}

variable "enable_guardduty" {
  description = "Enable GuardDuty threat detection"
  type        = bool
  default     = true
}

variable "enable_config" {
  description = "Enable AWS Config for compliance monitoring"
  type        = bool
  default     = true
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail for audit logging"
  type        = bool
  default     = true
}

# Compliance Configuration
variable "compliance_frameworks" {
  description = "List of compliance frameworks to adhere to"
  type        = list(string)
  default     = ["SOC2", "GDPR", "HIPAA"]
  validation {
    condition     = length(var.compliance_frameworks) >= 0
    error_message = "Compliance frameworks must be a valid list."
  }
}

variable "data_classification" {
  description = "Data classification level (public, internal, confidential, restricted)"
  type        = string
  default     = "confidential"
  validation {
    condition     = contains(["public", "internal", "confidential", "restricted"], var.data_classification)
    error_message = "Data classification must be one of: public, internal, confidential, restricted."
  }
}

# Database instance class alias for backward compatibility
variable "db_instance_class" {
  description = "RDS instance class (alias for database_instance_class)"
  type        = string
  default     = "db.t3.micro"
  validation {
    condition = contains([
      "db.t3.micro", "db.t3.small", "db.t3.medium",
      "db.t4g.micro", "db.t4g.small", "db.t4g.medium"
    ], var.db_instance_class)
    error_message = "Database instance class must be a valid RDS instance type."
  }
}

# Services alias for backward compatibility
variable "services" {
  description = "List of microservices to deploy (alias for microservices)"
  type        = list(string)
  default     = ["api-gateway", "user-service", "product-service", "order-service", "notification-service"]
  validation {
    condition     = length(var.services) > 0
    error_message = "At least one service must be specified."
  }
}

# Advanced Auto-scaling Configuration
variable "autoscaling_min_capacity" {
  description = "Minimum number of ECS service instances"
  type        = number
  default     = 1
  validation {
    condition     = var.autoscaling_min_capacity >= 1 && var.autoscaling_min_capacity <= 10
    error_message = "Autoscaling minimum capacity must be between 1 and 10."
  }
}

variable "autoscaling_max_capacity" {
  description = "Maximum number of ECS service instances"
  type        = number
  default     = 10
  validation {
    condition     = var.autoscaling_max_capacity >= 2 && var.autoscaling_max_capacity <= 50
    error_message = "Autoscaling maximum capacity must be between 2 and 50."
  }
}

variable "autoscaling_cpu_target" {
  description = "Target CPU utilization for auto-scaling"
  type        = number
  default     = 70
  validation {
    condition     = var.autoscaling_cpu_target >= 10 && var.autoscaling_cpu_target <= 90
    error_message = "Autoscaling CPU target must be between 10 and 90."
  }
}

variable "autoscaling_memory_target" {
  description = "Target memory utilization for auto-scaling"
  type        = number
  default     = 70
  validation {
    condition     = var.autoscaling_memory_target >= 10 && var.autoscaling_memory_target <= 90
    error_message = "Autoscaling memory target must be between 10 and 90."
  }
}

variable "autoscaling_request_target" {
  description = "Target request count per target for auto-scaling"
  type        = number
  default     = 1000
  validation {
    condition     = var.autoscaling_request_target >= 100 && var.autoscaling_request_target <= 10000
    error_message = "Autoscaling request target must be between 100 and 10000."
  }
}

variable "autoscaling_response_time_threshold" {
  description = "Response time threshold for auto-scaling (seconds)"
  type        = number
  default     = 2
  validation {
    condition     = var.autoscaling_response_time_threshold >= 0.5 && var.autoscaling_response_time_threshold <= 10
    error_message = "Autoscaling response time threshold must be between 0.5 and 10 seconds."
  }
}

variable "enable_predictive_scaling" {
  description = "Enable predictive scaling for ECS services"
  type        = bool
  default     = false
}

variable "enable_scheduled_scaling" {
  description = "Enable scheduled scaling for ECS services"
  type        = bool
  default     = false
}

variable "scale_up_schedule" {
  description = "Cron schedule for scaling up (e.g., weekday morning)"
  type        = string
  default     = "cron(0 8 * * MON-FRI *)"
}

variable "scale_down_schedule" {
  description = "Cron schedule for scaling down (e.g., weekday evening)"
  type        = string
  default     = "cron(0 20 * * MON-FRI *)"
}

# Performance Optimization Configuration
variable "enable_performance_mode" {
  description = "Enable performance optimization features"
  type        = bool
  default     = false
}

variable "enable_connection_draining" {
  description = "Enable connection draining for ALB targets"
  type        = bool
  default     = true
}

variable "connection_draining_timeout" {
  description = "Connection draining timeout in seconds"
  type        = number
  default     = 300
  validation {
    condition     = var.connection_draining_timeout >= 1 && var.connection_draining_timeout <= 3600
    error_message = "Connection draining timeout must be between 1 and 3600 seconds."
  }
}

# Load Testing Configuration
variable "enable_load_testing" {
  description = "Enable load testing infrastructure"
  type        = bool
  default     = false
}

variable "load_test_target_rps" {
  description = "Target requests per second for load testing"
  type        = number
  default     = 100
  validation {
    condition     = var.load_test_target_rps >= 10 && var.load_test_target_rps <= 10000
    error_message = "Load test target RPS must be between 10 and 10000."
  }
}

variable "load_test_duration" {
  description = "Load test duration in minutes"
  type        = number
  default     = 10
  validation {
    condition     = var.load_test_duration >= 1 && var.load_test_duration <= 120
    error_message = "Load test duration must be between 1 and 120 minutes."
  }
} 