# Phase 6: Monitoring và Security Setup

## Tổng quan

Phase 6 tập trung vào việc thiết lập monitoring, security, và compliance cho hệ thống Django microservices trên AWS ECS Fargate. Phase này bao gồm:

### 🔧 Monitoring Infrastructure
- **CloudWatch Monitoring**: Comprehensive metrics, logs, và alarms
- **CloudWatch Dashboards**: Real-time visualization
- **Application Performance Monitoring (APM)**: Service health tracking
- **Log Aggregation**: Centralized logging với advanced queries

### 🔐 Security Infrastructure
- **AWS WAF**: Web Application Firewall bảo vệ khỏi common attacks
- **GuardDuty**: Threat detection và anomaly detection
- **CloudTrail**: Audit logging cho API calls
- **AWS Config**: Compliance monitoring
- **VPC Flow Logs**: Network traffic monitoring

### 💾 Backup và Disaster Recovery
- **AWS Backup**: Automated backup strategy
- **Cross-region Replication**: Disaster recovery capability
- **Point-in-time Recovery**: Database backup strategy
- **Automated Health Checks**: Disaster recovery monitoring

## Kiến trúc Monitoring

```
┌─────────────────────────────────────────────────────────────────┐
│                    MONITORING ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │ ECS Services│    │ RDS Database│    │ Redis Cache │         │
│  │             │    │             │    │             │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│         │                   │                   │              │
│         └───────────────────┼───────────────────┘              │
│                             │                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                CloudWatch                               │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │   │
│  │  │   Metrics   │ │    Logs     │ │   Alarms    │       │   │
│  │  └─────────────┘ └─────────────┘ └─────────────┘       │   │
│  │                                                         │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │   │
│  │  │ Dashboards  │ │ Log Insights│ │ Composite   │       │   │
│  │  │             │ │             │ │ Alarms      │       │   │
│  │  └─────────────┘ └─────────────┘ └─────────────┘       │   │
│  └─────────────────────────────────────────────────────────┘   │
│                             │                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                  SNS Alerts                            │   │
│  │           ┌─────────────┐ ┌─────────────┐               │   │
│  │           │    Email    │ │    SMS      │               │   │
│  │           │   Alerts    │ │   Alerts    │               │   │
│  │           └─────────────┘ └─────────────┘               │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Security Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    SECURITY ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   Internet  │───▶│    WAF      │───▶│  ALB + SSL  │         │
│  │   Traffic   │    │(Rate Limit) │    │(HTTPS Only) │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│                                                │                │
│  ┌─────────────────────────────────────────────┼──────────────┐ │
│  │                   VPC                      │              │ │
│  │  ┌─────────────┐    ┌─────────────┐       │              │ │
│  │  │   Public    │    │   Private   │       │              │ │
│  │  │   Subnet    │    │   Subnet    │       │              │ │
│  │  │   (ALB)     │    │  (ECS/RDS)  │       │              │ │
│  │  └─────────────┘    └─────────────┘       │              │ │
│  │                                           │              │ │
│  │  ┌─────────────────────────────────────────┘              │ │
│  │  │                 ECS Services                           │ │
│  │  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐      │ │
│  │  │  │API Gateway  │ │User Service │ │Product Serv │      │ │
│  │  │  └─────────────┘ └─────────────┘ └─────────────┘      │ │
│  │  └─────────────────────────────────────────────────────────│ │
│  │                                                           │ │
│  │  ┌─────────────┐    ┌─────────────┐                      │ │
│  │  │ RDS (Private│    │Redis(Private│                      │ │
│  │  │   Subnet)   │    │   Subnet)   │                      │ │
│  │  └─────────────┘    └─────────────┘                      │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                Security Services                        │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │   │
│  │  │ GuardDuty   │ │ CloudTrail  │ │ AWS Config  │       │   │
│  │  │(Threat Det) │ │(Audit Log)  │ │(Compliance) │       │   │
│  │  └─────────────┘ └─────────────┘ └─────────────┘       │   │
│  │                                                         │   │
│  │  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐       │   │
│  │  │VPC Flow Log │ │   KMS       │ │   IAM       │       │   │
│  │  │(Network Mon)│ │(Encryption) │ │(Access Ctrl)│       │   │
│  │  └─────────────┘ └─────────────┘ └─────────────┘       │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Các thành phần chính

### 1. CloudWatch Monitoring (monitoring.tf)

#### CloudWatch Log Groups
```hcl
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/ecs/${var.project_name}-api-gateway"
  retention_in_days = var.log_retention_days
}
```

#### CloudWatch Alarms
- **ECS Service Alarms**: CPU, Memory utilization monitoring
- **RDS Alarms**: Database performance và connection monitoring
- **ALB Alarms**: Response time, error rate monitoring
- **ElastiCache Alarms**: Redis performance monitoring

#### CloudWatch Dashboard
- **Real-time Metrics**: Service performance visualization
- **Log Insights**: Advanced log querying capabilities
- **Composite Alarms**: Complex alerting logic

### 2. Security Infrastructure (security.tf)

#### Web Application Firewall (WAF)
```hcl
resource "aws_wafv2_web_acl" "main" {
  name  = "${var.project_name}-waf"
  scope = "REGIONAL"
  
  # Common attack protection
  # Rate limiting
  # Known bad inputs blocking
}
```

#### GuardDuty Threat Detection
```hcl
resource "aws_guardduty_detector" "main" {
  enable = true
  
  datasources {
    s3_logs { enable = true }
    malware_protection { ... }
  }
}
```

#### CloudTrail Audit Logging
```hcl
resource "aws_cloudtrail" "main" {
  name                         = "${var.project_name}-cloudtrail"
  s3_bucket_name              = aws_s3_bucket.cloudtrail.bucket
  include_global_service_events = true
  is_multi_region_trail       = true
  enable_log_file_validation  = true
}
```

#### AWS Config Compliance
```hcl
resource "aws_config_configuration_recorder" "main" {
  name     = "${var.project_name}-config-recorder"
  role_arn = aws_iam_role.config.arn
  
  recording_group {
    all_supported = true
    include_global_resource_types = true
  }
}
```

### 3. Backup và Disaster Recovery (backup.tf)

#### AWS Backup Strategy
```hcl
resource "aws_backup_plan" "main" {
  name = "${var.project_name}-backup-plan"
  
  rule {
    rule_name         = "daily_backups"
    schedule          = "cron(0 2 ? * * *)"
    lifecycle {
      cold_storage_after = 30
      delete_after      = 120
    }
  }
}
```

#### Cross-region Backup Replication
```hcl
resource "aws_s3_bucket_replication_configuration" "app_backups" {
  depends_on = [aws_s3_bucket_versioning.app_backups]
  
  role   = aws_iam_role.s3_replication[0].arn
  bucket = aws_s3_bucket.app_backups.id
}
```

#### Disaster Recovery Lambda
- **Health Check Function**: Monitors system health
- **Automated Recovery**: Triggers recovery procedures
- **Status Reporting**: Sends health reports via SNS

## Monitoring Tools

### 1. Dashboard Script (`monitoring/dashboard.sh`)

```bash
# Basic monitoring dashboard
./monitoring/dashboard.sh

# Watch mode (refresh every 30 seconds)
./monitoring/dashboard.sh --watch

# Show only services status
./monitoring/dashboard.sh --services-only

# Show infrastructure status
./monitoring/dashboard.sh --infra-only

# Show recent logs
./monitoring/dashboard.sh --logs-only

# Show cost estimates
./monitoring/dashboard.sh --cost-only
```

### 2. Python Monitoring Script (`monitoring/monitor.py`)

```python
# Install requirements
pip install boto3 tabulate

# Run monitoring
python monitoring/monitor.py --project django-microservices --environment dev

# JSON output
python monitoring/monitor.py --output json

# Continuous monitoring
python monitoring/monitor.py --watch --interval 60
```

## Security Features

### 1. Web Application Firewall (WAF)
- **Rate Limiting**: 2000 requests/minute per IP
- **Common Attack Protection**: SQL injection, XSS, etc.
- **Known Bad Inputs**: Malicious patterns blocking
- **Real-time Metrics**: Request monitoring

### 2. GuardDuty Threat Detection
- **Malware Detection**: EBS volume scanning
- **Anomaly Detection**: Unusual behavior patterns
- **Threat Intelligence**: Known malicious IPs
- **Automated Alerts**: SNS notifications

### 3. CloudTrail Audit Logging
- **API Call Logging**: All AWS API calls
- **Multi-region Trail**: Cross-region coverage
- **Log File Validation**: Integrity checking
- **S3 Storage**: Secure log storage

### 4. AWS Config Compliance
- **Resource Compliance**: Configuration drift detection
- **Compliance Rules**: Security best practices
- **Automated Remediation**: Policy enforcement
- **Compliance Reports**: Regular assessments

### 5. VPC Flow Logs
- **Network Traffic Monitoring**: All VPC traffic
- **Security Analysis**: Anomaly detection
- **Forensic Analysis**: Incident investigation
- **CloudWatch Integration**: Metrics và alarms

## Compliance Framework

### 1. Data Classification
```hcl
variable "data_classification" {
  description = "Data classification level"
  type        = string
  default     = "confidential"
}
```

### 2. Supported Compliance Standards
- **SOC 2**: Service Organization Control 2
- **GDPR**: General Data Protection Regulation  
- **HIPAA**: Health Insurance Portability and Accountability Act
- **PCI DSS**: Payment Card Industry Data Security Standard

### 3. Compliance Monitoring
- **AWS Config Rules**: Automated compliance checking
- **Regular Audits**: Scheduled compliance assessments
- **Remediation Tracking**: Non-compliance resolution
- **Reporting**: Compliance status reports

## Backup Strategy

### 1. RDS Backup
- **Automated Backups**: 7-day retention
- **Point-in-time Recovery**: 5-minute granularity
- **Cross-region Snapshots**: Disaster recovery
- **Backup Monitoring**: Failed backup alerts

### 2. Application Backup
- **S3 Backup Storage**: Application data backup
- **Lifecycle Management**: Cost optimization
- **Cross-region Replication**: Geographic redundancy
- **Versioning**: Multiple backup versions

### 3. Disaster Recovery
- **RDS Read Replicas**: Database failover
- **Lambda Health Checks**: Automated monitoring
- **Recovery Procedures**: Documented processes
- **Testing**: Regular DR testing

## Alerting Strategy

### 1. Alert Types
- **Critical**: System failures, security breaches
- **Warning**: Performance degradation, resource limits
- **Info**: Normal operational events

### 2. Notification Channels
- **Email**: Operations team notifications
- **SNS**: Integration với external systems
- **CloudWatch**: Dashboard alerts
- **Lambda**: Automated responses

### 3. Alert Thresholds
- **CPU Utilization**: >80% (warning), >90% (critical)
- **Memory Utilization**: >80% (warning), >90% (critical)
- **Response Time**: >1s (warning), >3s (critical)
- **Error Rate**: >5% (warning), >10% (critical)

## Performance Monitoring

### 1. Application Metrics
- **Request Rate**: Requests per second
- **Response Time**: Average response time
- **Error Rate**: HTTP 4xx/5xx errors
- **Throughput**: Data transfer metrics

### 2. Infrastructure Metrics
- **CPU Utilization**: Service CPU usage
- **Memory Utilization**: Service memory usage
- **Network I/O**: Network traffic patterns
- **Disk I/O**: Storage performance

### 3. Database Metrics
- **Connection Pool**: Active connections
- **Query Performance**: Slow query detection
- **Storage Usage**: Database storage growth
- **Backup Status**: Backup success/failure

## Cost Monitoring

### 1. Daily Cost Estimates
- **ECS Fargate**: ~$1.10/day (5 services)
- **RDS**: ~$0.44/day (db.t3.micro)
- **ElastiCache**: ~$0.40/day (cache.t3.micro)
- **NAT Gateway**: ~$1.35/day
- **ALB**: ~$0.65/day
- **Monitoring**: ~$0.24/day
- **Total**: ~$4.18/day

### 2. Cost Optimization
- **Right-sizing**: Optimal instance types
- **Reserved Instances**: Cost savings
- **Scheduled Scaling**: Off-hours scaling
- **Resource Cleanup**: Unused resource removal

## Troubleshooting Guide

### 1. Common Issues

#### Service Health Issues
```bash
# Check service status
./monitoring/dashboard.sh --services-only

# Check recent logs
./monitoring/dashboard.sh --logs-only

# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T01:00:00Z \
  --period 300 \
  --statistics Average
```

#### Database Connectivity Issues
```bash
# Check RDS status
aws rds describe-db-instances \
  --db-instance-identifier django-microservices-db

# Check security groups
aws ec2 describe-security-groups \
  --group-names django-microservices-rds-sg
```

#### High CPU/Memory Usage
```bash
# Scale up service
aws ecs update-service \
  --cluster django-microservices-cluster \
  --service django-microservices-api-gateway \
  --desired-count 3

# Check auto-scaling policies
aws application-autoscaling describe-scaling-policies \
  --service-namespace ecs
```

### 2. Log Analysis

#### Error Log Analysis
```bash
# Search for errors in logs
aws logs filter-log-events \
  --log-group-name "/ecs/django-microservices-api-gateway" \
  --filter-pattern "ERROR"

# Get recent application logs
aws logs get-log-events \
  --log-group-name "/ecs/django-microservices-api-gateway" \
  --log-stream-name "latest"
```

#### Performance Analysis
```bash
# Check ALB access logs
aws logs filter-log-events \
  --log-group-name "/aws/application-loadbalancer/django-microservices" \
  --filter-pattern "[timestamp, request_id, client_ip, client_port, target_ip, target_port, request_processing_time > 1.0]"
```

### 3. Security Incident Response

#### GuardDuty Findings
```bash
# Get GuardDuty findings
aws guardduty list-findings \
  --detector-id <detector-id>

# Get finding details
aws guardduty get-findings \
  --detector-id <detector-id> \
  --finding-ids <finding-id>
```

#### CloudTrail Analysis
```bash
# Check recent API calls
aws logs filter-log-events \
  --log-group-name "/aws/cloudtrail/django-microservices" \
  --filter-pattern "{ ($.errorCode = \"*UnauthorizedOperation\") || ($.errorCode = \"AccessDenied*\") }"
```

## Best Practices

### 1. Monitoring
- **Proactive Alerting**: Set up alerts before issues occur
- **Baseline Metrics**: Establish normal performance baselines
- **Regular Reviews**: Weekly monitoring reviews
- **Documentation**: Keep monitoring playbooks updated

### 2. Security
- **Least Privilege**: Minimum required permissions
- **Regular Audits**: Monthly security assessments
- **Incident Response**: Documented response procedures
- **Compliance**: Regular compliance checks

### 3. Backup
- **Regular Testing**: Monthly backup restoration tests
- **Multiple Copies**: 3-2-1 backup strategy
- **Automation**: Automated backup processes
- **Documentation**: Recovery procedures

### 4. Cost Management
- **Regular Reviews**: Monthly cost analysis
- **Right-sizing**: Optimize resource allocation
- **Reserved Capacity**: Use reserved instances
- **Cleanup**: Remove unused resources

## Implementation Timeline

### Week 1: Core Monitoring Setup
- [ ] Deploy CloudWatch monitoring infrastructure
- [ ] Set up basic alerts và dashboards
- [ ] Configure log aggregation
- [ ] Test monitoring tools

### Week 2: Security Implementation
- [ ] Deploy WAF và GuardDuty
- [ ] Configure CloudTrail và AWS Config
- [ ] Set up VPC Flow Logs
- [ ] Security testing và validation

### Week 3: Backup và DR
- [ ] Implement backup strategy
- [ ] Set up cross-region replication
- [ ] Configure disaster recovery
- [ ] Test backup và recovery procedures

### Week 4: Optimization và Documentation
- [ ] Performance tuning
- [ ] Cost optimization
- [ ] Documentation updates
- [ ] Team training

## Kết luận

Phase 6 cung cấp comprehensive monitoring, security, và backup infrastructure cho Django microservices system. Với các công cụ và processes được thiết lập, team có thể:

- **Proactively Monitor**: Detect issues before they impact users
- **Ensure Security**: Protect against threats và maintain compliance
- **Recover Quickly**: Minimize downtime với robust backup strategy
- **Optimize Costs**: Maintain efficient resource utilization

Hệ thống monitoring và security này tạo foundation cho production-ready deployment với high availability, security, và reliability.

## Tài liệu liên quan

- [AWS CloudWatch Documentation](https://docs.aws.amazon.com/cloudwatch/)
- [AWS Security Best Practices](https://docs.aws.amazon.com/security/)
- [AWS Backup User Guide](https://docs.aws.amazon.com/aws-backup/)
- [Disaster Recovery Best Practices](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/disaster-recovery-dr-objectives.html) 