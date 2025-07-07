# Main Terraform Configuration
# Modular deployment for Django Microservices on AWS ECS Fargate

# Core Infrastructure Module (Phase 2)
# This module contains essential infrastructure components
module "core" {
  source = "./core"
  
  # Core project variables
  project_name = var.project_name
  environment = var.environment
  aws_region = var.aws_region
  
  # VPC Configuration
  vpc_cidr = var.vpc_cidr
  availability_zones = var.availability_zones
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
  
  # Database Configuration
  database_instance_class = var.database_instance_class
  database_allocated_storage = var.database_allocated_storage
  database_max_allocated_storage = var.database_max_allocated_storage
  database_backup_retention_period = var.database_backup_retention_period
  database_multi_az = var.database_multi_az
  database_deletion_protection = var.database_deletion_protection
  
  # Redis Configuration
  redis_node_type = var.redis_node_type
  redis_num_cache_nodes = var.redis_num_cache_nodes
  
  # ECS Configuration
  ecs_task_cpu = var.ecs_task_cpu
  ecs_task_memory = var.ecs_task_memory
  ecs_service_desired_count = var.ecs_service_desired_count
  
  # Microservices Configuration
  microservices = var.microservices
  microservice_ports = var.microservice_ports
  
  # Security and Networking
  allowed_cidr_blocks = var.allowed_cidr_blocks
  enable_deletion_protection = var.enable_deletion_protection
  
  # Logging
  log_retention_days = var.log_retention_days
  
  # Tags
  additional_tags = var.additional_tags
}

# Advanced Infrastructure Module (Phase 6-7)
# This module contains advanced features like monitoring, security, backup
module "advanced" {
  source = "./advanced"
  count = var.enable_advanced_features ? 1 : 0
  
  # Dependencies from core module
  vpc_id = module.core.vpc_id
  private_subnet_ids = module.core.private_subnet_ids
  public_subnet_ids = module.core.public_subnet_ids
  ecs_cluster_name = module.core.ecs_cluster_name
  ecs_cluster_arn = module.core.ecs_cluster_arn
  alb_arn = module.core.alb_arn
  alb_dns_name = module.core.alb_dns_name
  database_endpoint = module.core.database_endpoint
  redis_endpoint = module.core.redis_endpoint
  
  # Core variables
  project_name = var.project_name
  environment = var.environment
  aws_region = var.aws_region
  
  # Advanced feature flags
  enable_monitoring = var.enable_monitoring
  enable_security = var.enable_security
  enable_backup = var.enable_backup
  enable_autoscaling = var.enable_autoscaling
  enable_performance = var.enable_performance
  enable_cost_optimization = var.enable_cost_optimization
  enable_load_testing = var.enable_load_testing
  
  # Monitoring configuration
  alert_email_addresses = var.alert_email_addresses
  security_email_addresses = var.security_email_addresses
  
  # Backup configuration
  enable_cross_region_backup = var.enable_cross_region_backup
  backup_retention_period = var.backup_retention_period
  
  # Auto-scaling configuration
  autoscaling_min_capacity = var.autoscaling_min_capacity
  autoscaling_max_capacity = var.autoscaling_max_capacity
  autoscaling_cpu_target = var.autoscaling_cpu_target
  
  # Performance configuration
  enable_performance_mode = var.enable_performance_mode
  
  # Cost optimization
  enable_spot_instances = var.enable_spot_instances
  
  # Tags
  additional_tags = var.additional_tags
}

# Outputs from core module
output "core_outputs" {
  description = "Outputs from core infrastructure module"
  value = {
    vpc_id = module.core.vpc_id
    public_subnet_ids = module.core.public_subnet_ids
    private_subnet_ids = module.core.private_subnet_ids
    ecs_cluster_name = module.core.ecs_cluster_name
    ecs_cluster_arn = module.core.ecs_cluster_arn
    alb_dns_name = module.core.alb_dns_name
    alb_arn = module.core.alb_arn
    database_endpoint = module.core.database_endpoint
    redis_endpoint = module.core.redis_endpoint
  }
}

# Outputs from advanced module (conditional)
output "advanced_outputs" {
  description = "Outputs from advanced infrastructure module"
  value = var.enable_advanced_features ? {
    monitoring_dashboard_url = module.advanced[0].monitoring_dashboard_url
    waf_web_acl_arn = module.advanced[0].waf_web_acl_arn
    backup_vault_arn = module.advanced[0].backup_vault_arn
    cloudfront_distribution_domain = module.advanced[0].cloudfront_distribution_domain
  } : null
}

# Summary output
output "deployment_summary" {
  description = "Summary of deployed infrastructure"
  value = {
    project_name = var.project_name
    environment = var.environment
    region = var.aws_region
    core_deployed = true
    advanced_deployed = var.enable_advanced_features
    estimated_monthly_cost = var.enable_advanced_features ? "$190" : "$75"
    deployment_date = timestamp()
  }
} 