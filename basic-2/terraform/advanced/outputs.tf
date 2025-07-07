# Advanced Infrastructure Outputs
# Phase 6-7: Advanced Features

# Monitoring Outputs
output "monitoring_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = var.enable_monitoring ? "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${var.project_name}-dashboard" : null
}

output "sns_topic_arns" {
  description = "ARNs of SNS topics for alerts"
  value       = var.enable_monitoring ? {
    alerts   = try(aws_sns_topic.alerts[0].arn, null)
    security = try(aws_sns_topic.security_alerts[0].arn, null)
  } : null
}

output "cloudwatch_log_groups" {
  description = "Names of additional CloudWatch log groups"
  value       = var.enable_monitoring ? {
    vpc_flow_logs = try(aws_cloudwatch_log_group.vpc_flow_log[0].name, null)
    security_logs = try(aws_cloudwatch_log_group.security[0].name, null)
  } : null
}

# Security Outputs
output "waf_web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = var.enable_security && var.enable_waf ? try(aws_wafv2_web_acl.main[0].arn, null) : null
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = var.enable_security && var.enable_guardduty ? try(aws_guardduty_detector.main[0].id, null) : null
}

output "cloudtrail_arn" {
  description = "ARN of the CloudTrail"
  value       = var.enable_security && var.enable_cloudtrail ? try(aws_cloudtrail.main[0].arn, null) : null
}

output "kms_key_arns" {
  description = "ARNs of KMS keys created"
  value       = var.enable_security ? {
    guardduty = try(aws_kms_key.guardduty[0].arn, null)
    backup    = try(aws_kms_key.backup[0].arn, null)
  } : null
}

# Backup Outputs
output "backup_vault_arn" {
  description = "ARN of the backup vault"
  value       = var.enable_backup ? try(aws_backup_vault.main[0].arn, null) : null
}

output "backup_plan_arn" {
  description = "ARN of the backup plan"
  value       = var.enable_backup ? try(aws_backup_plan.main[0].arn, null) : null
}

output "disaster_recovery_lambda_arn" {
  description = "ARN of the disaster recovery Lambda function"
  value       = var.enable_backup ? try(aws_lambda_function.disaster_recovery[0].arn, null) : null
}

# Auto-scaling Outputs
output "autoscaling_group_arns" {
  description = "ARNs of auto-scaling groups"
  value       = var.enable_autoscaling ? {
    ecs_services = try([for k, v in aws_appautoscaling_target.ecs_target : v.resource_id], [])
  } : null
}

output "scaling_policies" {
  description = "Auto-scaling policies created"
  value       = var.enable_autoscaling ? {
    cpu_policies    = try([for k, v in aws_appautoscaling_policy.ecs_cpu : v.arn], [])
    memory_policies = try([for k, v in aws_appautoscaling_policy.ecs_memory : v.arn], [])
  } : null
}

# Performance Outputs
output "cloudfront_distribution_domain" {
  description = "Domain name of the CloudFront distribution"
  value       = var.enable_performance && var.enable_cloudfront ? try(aws_cloudfront_distribution.main[0].domain_name, null) : null
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = var.enable_performance && var.enable_cloudfront ? try(aws_cloudfront_distribution.main[0].id, null) : null
}

output "redis_cluster_endpoints" {
  description = "Enhanced Redis cluster endpoints"
  value       = var.enable_performance ? {
    primary_endpoint   = try(aws_elasticache_replication_group.enhanced[0].primary_endpoint_address, null)
    reader_endpoint    = try(aws_elasticache_replication_group.enhanced[0].reader_endpoint_address, null)
    configuration_endpoint = try(aws_elasticache_replication_group.enhanced[0].configuration_endpoint_address, null)
  } : null
}

output "database_read_replica_endpoints" {
  description = "RDS read replica endpoints"
  value       = var.enable_performance && var.enable_read_replicas ? try([for k, v in aws_db_instance.read_replica : v.endpoint], []) : null
}

# Cost Optimization Outputs
output "spot_fleet_id" {
  description = "ID of the spot fleet"
  value       = var.enable_cost_optimization && var.enable_spot_instances ? try(aws_spot_fleet_request.main[0].id, null) : null
}

output "reserved_capacity_offerings" {
  description = "Information about reserved capacity offerings"
  value       = var.enable_cost_optimization ? {
    recommendations = "Check AWS Cost Explorer for Reserved Instance recommendations"
    savings_plans   = "Review Savings Plans in AWS Billing console"
  } : null
}

# Load Testing Outputs
output "load_testing_lambda_arn" {
  description = "ARN of the load testing Lambda function"
  value       = var.enable_load_testing ? try(aws_lambda_function.load_testing[0].arn, null) : null
}

output "load_testing_eventbridge_rule" {
  description = "Name of the EventBridge rule for scheduled load testing"
  value       = var.enable_load_testing ? try(aws_cloudwatch_event_rule.load_testing_schedule[0].name, null) : null
}

# Network Performance Outputs
output "vpc_endpoints" {
  description = "VPC endpoints created for performance"
  value       = var.enable_performance ? {
    s3_endpoint  = try(aws_vpc_endpoint.s3[0].id, null)
    ecr_endpoint = try(aws_vpc_endpoint.ecr[0].id, null)
  } : null
}

# Security Compliance Outputs
output "config_recorder_name" {
  description = "Name of the AWS Config recorder"
  value       = var.enable_security && var.enable_config ? try(aws_config_configuration_recorder.main[0].name, null) : null
}

output "compliance_dashboard_url" {
  description = "URL to the compliance dashboard"
  value       = var.enable_security && var.enable_config ? "https://${var.aws_region}.console.aws.amazon.com/config/home?region=${var.aws_region}#/dashboard" : null
}

# ECS Services Outputs
output "ecs_service_arns" {
  description = "ARNs of ECS services"
  value       = try({
    for k, v in aws_ecs_service.microservices : k => v.id
  }, {})
}

output "ecs_task_definition_arns" {
  description = "ARNs of ECS task definitions"
  value       = try({
    for k, v in aws_ecs_task_definition.microservices : k => v.arn
  }, {})
}

# Summary Outputs
output "advanced_features_enabled" {
  description = "Summary of enabled advanced features"
  value = {
    monitoring        = var.enable_monitoring
    security         = var.enable_security
    backup           = var.enable_backup
    autoscaling      = var.enable_autoscaling
    performance      = var.enable_performance
    cost_optimization = var.enable_cost_optimization
    load_testing     = var.enable_load_testing
  }
}

output "estimated_monthly_cost" {
  description = "Estimated monthly cost for advanced features"
  value = var.enable_monitoring && var.enable_security && var.enable_backup ? "~$115-150/month" : "~$50-75/month"
}

output "deployment_timestamp" {
  description = "Timestamp of deployment"
  value       = timestamp()
} 