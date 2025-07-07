# Advanced Auto-scaling Configuration
# This file contains advanced auto-scaling policies with predictive scaling and custom metrics

# Application Auto Scaling Target for each service
resource "aws_appautoscaling_target" "ecs_target" {
  count              = length(var.services)
  max_capacity       = var.autoscaling_max_capacity
  min_capacity       = var.autoscaling_min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main[count.index].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  tags = {
    Name        = "${var.project_name}-${var.services[count.index]}-autoscaling-target"
    Environment = var.environment
    Service     = var.services[count.index]
  }
}

# CPU-based scaling policy
resource "aws_appautoscaling_policy" "ecs_cpu_policy" {
  count              = length(var.services)
  name               = "${var.project_name}-${var.services[count.index]}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[count.index].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[count.index].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[count.index].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.autoscaling_cpu_target
    scale_out_cooldown = 300
    scale_in_cooldown  = 300
  }

  tags = {
    Name        = "${var.project_name}-${var.services[count.index]}-cpu-scaling"
    Environment = var.environment
    Service     = var.services[count.index]
  }
}

# Memory-based scaling policy
resource "aws_appautoscaling_policy" "ecs_memory_policy" {
  count              = length(var.services)
  name               = "${var.project_name}-${var.services[count.index]}-memory-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[count.index].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[count.index].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[count.index].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value       = var.autoscaling_memory_target
    scale_out_cooldown = 300
    scale_in_cooldown  = 300
  }

  tags = {
    Name        = "${var.project_name}-${var.services[count.index]}-memory-scaling"
    Environment = var.environment
    Service     = var.services[count.index]
  }
}

# ALB Request Count based scaling policy
resource "aws_appautoscaling_policy" "ecs_request_count_policy" {
  count              = length(var.services)
  name               = "${var.project_name}-${var.services[count.index]}-request-count-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[count.index].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[count.index].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[count.index].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.main[count.index].arn_suffix}"
    }
    target_value       = var.autoscaling_request_target
    scale_out_cooldown = 180
    scale_in_cooldown  = 300
  }

  tags = {
    Name        = "${var.project_name}-${var.services[count.index]}-request-count-scaling"
    Environment = var.environment
    Service     = var.services[count.index]
  }
}

# Custom CloudWatch metric for application-specific scaling
resource "aws_cloudwatch_metric_alarm" "custom_response_time_high" {
  count               = length(var.services)
  alarm_name          = "${var.project_name}-${var.services[count.index]}-custom-response-time-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = var.autoscaling_response_time_threshold
  alarm_description   = "This metric monitors ALB target response time for ${var.services[count.index]}"
  alarm_actions       = [aws_appautoscaling_policy.ecs_step_scale_out[count.index].arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.main[count.index].arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-${var.services[count.index]}-response-time-alarm"
    Environment = var.environment
    Service     = var.services[count.index]
  }
}

resource "aws_cloudwatch_metric_alarm" "custom_response_time_low" {
  count               = length(var.services)
  alarm_name          = "${var.project_name}-${var.services[count.index]}-custom-response-time-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Average"
  threshold           = var.autoscaling_response_time_threshold * 0.5
  alarm_description   = "This metric monitors ALB target response time for scale-in"
  alarm_actions       = [aws_appautoscaling_policy.ecs_step_scale_in[count.index].arn]

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.main[count.index].arn_suffix
  }

  tags = {
    Name        = "${var.project_name}-${var.services[count.index]}-response-time-low-alarm"
    Environment = var.environment
    Service     = var.services[count.index]
  }
}

# Step scaling policies for more aggressive scaling
resource "aws_appautoscaling_policy" "ecs_step_scale_out" {
  count              = length(var.services)
  name               = "${var.project_name}-${var.services[count.index]}-step-scale-out"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[count.index].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[count.index].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[count.index].service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown               = 180
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      metric_interval_upper_bound = 1
      scaling_adjustment          = 1
    }

    step_adjustment {
      metric_interval_lower_bound = 1
      metric_interval_upper_bound = 2
      scaling_adjustment          = 2
    }

    step_adjustment {
      metric_interval_lower_bound = 2
      scaling_adjustment          = 3
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.services[count.index]}-step-scale-out"
    Environment = var.environment
    Service     = var.services[count.index]
  }
}

resource "aws_appautoscaling_policy" "ecs_step_scale_in" {
  count              = length(var.services)
  name               = "${var.project_name}-${var.services[count.index]}-step-scale-in"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[count.index].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[count.index].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[count.index].service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown               = 300
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_upper_bound = 0
      scaling_adjustment          = -1
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.services[count.index]}-step-scale-in"
    Environment = var.environment
    Service     = var.services[count.index]
  }
}

# Predictive scaling (requires ECS service with predictive scaling enabled)
# Note: This is a placeholder for future predictive scaling configuration
resource "aws_appautoscaling_policy" "ecs_predictive_scaling" {
  count              = var.enable_predictive_scaling ? length(var.services) : 0
  name               = "${var.project_name}-${var.services[count.index]}-predictive-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[count.index].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[count.index].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[count.index].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.autoscaling_cpu_target
    scale_out_cooldown = 180
    scale_in_cooldown  = 300

    # Enhanced scaling configuration
    disable_scale_in = false
  }

  tags = {
    Name        = "${var.project_name}-${var.services[count.index]}-predictive-scaling"
    Environment = var.environment
    Service     = var.services[count.index]
  }
}

# Scheduled scaling for predictable load patterns
resource "aws_appautoscaling_scheduled_action" "ecs_scheduled_scale_up" {
  count              = var.enable_scheduled_scaling ? length(var.services) : 0
  name               = "${var.project_name}-${var.services[count.index]}-scheduled-scale-up"
  service_namespace  = aws_appautoscaling_target.ecs_target[count.index].service_namespace
  resource_id        = aws_appautoscaling_target.ecs_target[count.index].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[count.index].scalable_dimension

  schedule = var.scale_up_schedule # e.g., "cron(0 8 * * MON-FRI *)" for weekdays 8 AM

  scalable_target_action {
    min_capacity = var.autoscaling_min_capacity
    max_capacity = var.autoscaling_max_capacity * 2
  }

  tags = {
    Name        = "${var.project_name}-${var.services[count.index]}-scheduled-scale-up"
    Environment = var.environment
    Service     = var.services[count.index]
  }
}

resource "aws_appautoscaling_scheduled_action" "ecs_scheduled_scale_down" {
  count              = var.enable_scheduled_scaling ? length(var.services) : 0
  name               = "${var.project_name}-${var.services[count.index]}-scheduled-scale-down"
  service_namespace  = aws_appautoscaling_target.ecs_target[count.index].service_namespace
  resource_id        = aws_appautoscaling_target.ecs_target[count.index].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[count.index].scalable_dimension

  schedule = var.scale_down_schedule # e.g., "cron(0 20 * * MON-FRI *)" for weekdays 8 PM

  scalable_target_action {
    min_capacity = var.autoscaling_min_capacity
    max_capacity = var.autoscaling_max_capacity
  }

  tags = {
    Name        = "${var.project_name}-${var.services[count.index]}-scheduled-scale-down"
    Environment = var.environment
    Service     = var.services[count.index]
  }
}

# Custom CloudWatch dashboard for auto-scaling metrics
resource "aws_cloudwatch_dashboard" "autoscaling_dashboard" {
  dashboard_name = "${var.project_name}-autoscaling-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            for i, service in var.services : [
              "AWS/ECS", "RunningTaskCount", "ServiceName", "${var.project_name}-${service}", "ClusterName", aws_ecs_cluster.main.name
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ECS Service Running Task Count"
          period  = 300
          yAxis = {
            left = {
              min = 0
              max = var.autoscaling_max_capacity * 2
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            for i, service in var.services : [
              "AWS/ECS", "CPUUtilization", "ServiceName", "${var.project_name}-${service}", "ClusterName", aws_ecs_cluster.main.name
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ECS Service CPU Utilization"
          period  = 300
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            for i, service in var.services : [
              "AWS/ECS", "MemoryUtilization", "ServiceName", "${var.project_name}-${service}", "ClusterName", aws_ecs_cluster.main.name
            ]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ECS Service Memory Utilization"
          period  = 300
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix],
            [".", "TargetResponseTime", ".", "."],
            [".", "ActiveConnectionCount", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Load Balancer Metrics"
          period  = 300
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-autoscaling-dashboard"
    Environment = var.environment
  }
}

# CloudWatch Alarms for auto-scaling monitoring
resource "aws_cloudwatch_metric_alarm" "scaling_activity_alarm" {
  count               = length(var.services)
  alarm_name          = "${var.project_name}-${var.services[count.index]}-scaling-activity"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ScalingActivity"
  namespace           = "AWS/ApplicationAutoScaling"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors excessive scaling activity for ${var.services[count.index]}"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceNamespace  = "ecs"
    ResourceId        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main[count.index].name}"
    ScalableDimension = "ecs:service:DesiredCount"
  }

  tags = {
    Name        = "${var.project_name}-${var.services[count.index]}-scaling-activity-alarm"
    Environment = var.environment
    Service     = var.services[count.index]
  }
} 