# Variables for Advanced Infrastructure Module
# Phase 6-7: Advanced Features

# Core dependencies (passed from core module)
variable "vpc_id" {
  description = "VPC ID from core module"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs from core module"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs from core module"
  type        = list(string)
}

variable "ecs_cluster_name" {
  description = "ECS cluster name from core module"
  type        = string
}

variable "ecs_cluster_arn" {
  description = "ECS cluster ARN from core module"
  type        = string
}

variable "alb_arn" {
  description = "ALB ARN from core module"
  type        = string
}

variable "alb_dns_name" {
  description = "ALB DNS name from core module"
  type        = string
}

variable "database_endpoint" {
  description = "Database endpoint from core module"
  type        = string
  sensitive   = true
}

variable "redis_endpoint" {
  description = "Redis endpoint from core module"
  type        = string
  sensitive   = true
}

# Project Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# Feature Flags
variable "enable_monitoring" {
  description = "Enable advanced monitoring features"
  type        = bool
  default     = true
}

variable "enable_security" {
  description = "Enable security features (WAF, GuardDuty)"
  type        = bool
  default     = true
}

variable "enable_backup" {
  description = "Enable backup and disaster recovery"
  type        = bool
  default     = true
}

variable "enable_autoscaling" {
  description = "Enable advanced auto-scaling"
  type        = bool
  default     = true
}

variable "enable_performance" {
  description = "Enable performance optimization"
  type        = bool
  default     = true
}

variable "enable_cost_optimization" {
  description = "Enable cost optimization features"
  type        = bool
  default     = true
}

variable "enable_load_testing" {
  description = "Enable load testing infrastructure"
  type        = bool
  default     = false
}

# Monitoring Configuration
variable "alert_email_addresses" {
  description = "List of email addresses for alerts"
  type        = list(string)
  default     = []
}

variable "security_email_addresses" {
  description = "List of email addresses for security alerts"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

# Backup Configuration
variable "enable_cross_region_backup" {
  description = "Enable cross-region backup replication"
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

# Auto-scaling Configuration
variable "autoscaling_min_capacity" {
  description = "Minimum capacity for auto-scaling"
  type        = number
  default     = 1
}

variable "autoscaling_max_capacity" {
  description = "Maximum capacity for auto-scaling"
  type        = number
  default     = 10
}

variable "autoscaling_cpu_target" {
  description = "Target CPU utilization for auto-scaling"
  type        = number
  default     = 70
}

variable "autoscaling_memory_target" {
  description = "Target memory utilization for auto-scaling"
  type        = number
  default     = 70
}

# Performance Configuration
variable "enable_performance_mode" {
  description = "Enable performance mode features"
  type        = bool
  default     = false
}

variable "enable_cloudfront" {
  description = "Enable CloudFront CDN"
  type        = bool
  default     = true
}

variable "enable_read_replicas" {
  description = "Enable RDS read replicas"
  type        = bool
  default     = false
}

# Cost Optimization
variable "enable_spot_instances" {
  description = "Enable spot instances for cost optimization"
  type        = bool
  default     = false
}

variable "enable_scheduled_scaling" {
  description = "Enable scheduled scaling for predictable workloads"
  type        = bool
  default     = true
}

# Security Configuration
variable "enable_waf" {
  description = "Enable Web Application Firewall"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Enable GuardDuty threat detection"
  type        = bool
  default     = true
}

variable "enable_config" {
  description = "Enable AWS Config for compliance"
  type        = bool
  default     = true
}

variable "enable_cloudtrail" {
  description = "Enable CloudTrail for API logging"
  type        = bool
  default     = true
}

# Load Testing Configuration
variable "load_test_duration" {
  description = "Duration of load tests in seconds"
  type        = number
  default     = 300
}

variable "load_test_concurrent_users" {
  description = "Number of concurrent users for load testing"
  type        = number
  default     = 100
}

# Tags
variable "additional_tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
} 