# Core Infrastructure - Phase 2

## 📁 Core Infrastructure Components

This directory contains the **basic infrastructure** components needed for Django microservices deployment on AWS ECS Fargate.

### 🏗️ **Files in Core Directory**

1. **`vpc.tf`** - VPC và Network Infrastructure
   - VPC với DNS support
   - Public/Private subnets
   - Internet Gateway
   - NAT Gateway (cost-optimized)
   - Route tables và associations
   - VPC Flow Logs cho security

2. **`security-groups.tf`** - Security Groups
   - ALB Security Group (HTTP/HTTPS)
   - ECS Tasks Security Group (containers)
   - RDS Security Group (PostgreSQL)
   - Redis Security Group (ElastiCache)
   - VPC Endpoints Security Group

3. **`ecs.tf`** - ECS Cluster và IAM
   - ECS Fargate Cluster
   - Container Insights enabled
   - ECS Task Execution Role
   - ECS Task Role (application permissions)
   - CloudWatch Log Groups cho services

4. **`rds.tf`** - PostgreSQL Database
   - RDS PostgreSQL 14.9
   - Multi-AZ configuration
   - Enhanced Monitoring
   - Performance Insights
   - Automated backups
   - SSM Parameter Store cho credentials

5. **`redis.tf`** - ElastiCache Redis
   - Redis 7.0 cluster
   - Encryption at rest và in transit
   - CloudWatch monitoring
   - SSM Parameter Store cho connection

6. **`alb.tf`** - Application Load Balancer
   - ALB với Target Groups
   - Routing rules cho microservices
   - Health checks
   - Access logs to S3

## 🚀 **Deployment Strategy**

### **Phase 2 Only (Core Infrastructure)**
```bash
# Deploy only core components
cd terraform/core
terraform init
terraform plan -var-file="../configuration/terraform.tfvars.simple"
terraform apply -var-file="../configuration/terraform.tfvars.simple"
```

### **Variables Required**
Core infrastructure requires these variables from `../configuration/variables.tf`:
- `project_name`
- `environment` 
- `aws_region`
- `vpc_cidr`
- `availability_zones`
- `database_instance_class`
- `redis_node_type`
- `microservices`
- `microservice_ports`

## 📊 **Resources Created**

- **1x** VPC với 2 AZs
- **2x** Public Subnets
- **2x** Private Subnets  
- **1x** Internet Gateway
- **1x** NAT Gateway (single for cost optimization)
- **4x** Security Groups
- **1x** ECS Cluster
- **1x** RDS PostgreSQL instance
- **1x** ElastiCache Redis cluster
- **1x** Application Load Balancer
- **Multiple** CloudWatch Log Groups
- **Multiple** IAM Roles và Policies

## 💰 **Cost Estimation (Monthly)**

- **VPC/Networking**: ~$32/month (NAT Gateway)
- **ECS Cluster**: $0 (no tasks running)
- **RDS db.t3.micro**: ~$13/month
- **Redis cache.t3.micro**: ~$12/month
- **ALB**: ~$16/month
- **CloudWatch Logs**: ~$2/month
- **Total Core**: ~$75/month

## 🔗 **Dependencies**

Core infrastructure has **no dependencies** và có thể deploy independently. Advanced features trong `../advanced/` depend on core infrastructure.

## 🔧 **Next Steps**

After deploying core infrastructure:
1. Deploy ECS services và task definitions
2. Enable monitoring features
3. Setup CI/CD pipeline
4. Add advanced features (security, backup, auto-scaling) 