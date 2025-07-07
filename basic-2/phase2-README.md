# Phase 2: Setup Infrastructure với Terraform

## 🎯 Mục Tiêu
Triển khai infrastructure trên AWS sử dụng Terraform, bao gồm VPC, ECS Cluster, RDS, ElastiCache, và các thành phần mạng.

## 📋 Các Bước Thực Hiện

### 1. Tạo Terraform Configuration Files

#### VPC và Network (`terraform/vpc.tf`)
- ✅ **VPC**: 10.0.0.0/16 với DNS support
- ✅ **Internet Gateway**: Kết nối internet
- ✅ **Public Subnets**: 2 subnets cho ALB và NAT Gateway
- ✅ **Private Subnets**: 2 subnets cho ECS tasks
- ✅ **NAT Gateway**: Outbound internet cho private subnets
- ✅ **Route Tables**: Routing configuration

#### Security Groups (`terraform/security.tf`)
- ✅ **ALB Security Group**: HTTP/HTTPS traffic
- ✅ **ECS Security Group**: Container traffic
- ✅ **RDS Security Group**: Database access
- ✅ **Redis Security Group**: Cache access

#### ECS Cluster (`terraform/ecs.tf`)
- ✅ **ECS Cluster**: Fargate cluster
- ✅ **IAM Roles**: Task execution và task roles
- ✅ **CloudWatch Log Groups**: Container logging

#### Database (`terraform/rds.tf`)
- ✅ **RDS Subnet Group**: Multi-AZ deployment
- ✅ **RDS Instance**: PostgreSQL 14
- ✅ **Parameter Group**: Optimized configuration
- ✅ **Backup Configuration**: Automated backups

#### Caching (`terraform/redis.tf`)
- ✅ **ElastiCache Subnet Group**: Redis deployment
- ✅ **Redis Cluster**: High availability
- ✅ **Parameter Group**: Redis configuration

#### Load Balancer (`terraform/alb.tf`)
- ✅ **Application Load Balancer**: Public-facing
- ✅ **Target Groups**: Service-specific targets
- ✅ **Listeners**: HTTP/HTTPS routing
- ✅ **Health Checks**: Service health monitoring

#### Variables (`terraform/variables.tf`)
- ✅ **Project Configuration**: Name, environment, region
- ✅ **Network Configuration**: CIDR blocks, AZ count
- ✅ **Database Configuration**: Instance type, storage
- ✅ **ECS Configuration**: Task resources, scaling

### 2. Terraform Provider Configuration (`terraform/providers.tf`)
```hcl
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
```

### 3. Outputs Configuration (`terraform/outputs.tf`)
- ✅ **VPC Information**: VPC ID, subnet IDs
- ✅ **Security Groups**: Security group IDs
- ✅ **ALB**: DNS name, zone ID
- ✅ **RDS**: Endpoint, port
- ✅ **Redis**: Endpoint, port
- ✅ **ECS**: Cluster name, ARN

### 4. Infrastructure Deployment
```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan deployment
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan
```

## 🏗️ Infrastructure Components

### Network Architecture
```
VPC (10.0.0.0/16)
├── Public Subnets
│   ├── 10.0.1.0/24 (AZ-a)
│   └── 10.0.2.0/24 (AZ-b)
├── Private Subnets
│   ├── 10.0.10.0/24 (AZ-a)
│   └── 10.0.20.0/24 (AZ-b)
├── Internet Gateway
├── NAT Gateway (AZ-a)
└── Route Tables
```

### Security Groups
- **ALB SG**: Ports 80, 443 from internet
- **ECS SG**: Ports 8000-8004 from ALB
- **RDS SG**: Port 5432 from ECS
- **Redis SG**: Port 6379 from ECS

### Database Configuration
- **Engine**: PostgreSQL 14
- **Instance Class**: db.t3.micro
- **Storage**: 20GB GP2
- **Multi-AZ**: Enabled
- **Backup**: 7 days retention

### Cache Configuration
- **Engine**: Redis 7
- **Node Type**: cache.t3.micro
- **Parameter Group**: Default
- **Subnet Group**: Multi-AZ

## 🔧 Terraform Files Created

### Core Infrastructure
- `terraform/providers.tf` - Provider configuration
- `terraform/variables.tf` - Input variables
- `terraform/vpc.tf` - VPC và networking
- `terraform/security.tf` - Security groups
- `terraform/ecs.tf` - ECS cluster
- `terraform/rds.tf` - PostgreSQL database
- `terraform/redis.tf` - Redis cache
- `terraform/alb.tf` - Application Load Balancer
- `terraform/outputs.tf` - Output values

### Configuration Files
- `terraform/terraform.tfvars.example` - Example variables
- `terraform/.gitignore` - Git ignore rules

## 📊 Kết Quả Đạt Được

✅ **VPC Network** - Complete network infrastructure
✅ **ECS Cluster** - Ready for container deployment
✅ **RDS Database** - PostgreSQL cluster running
✅ **Redis Cache** - ElastiCache cluster active
✅ **Load Balancer** - ALB configured with target groups
✅ **Security** - Proper security group configuration
✅ **Monitoring** - CloudWatch log groups created
✅ **IAM** - Service roles and policies

## 🔍 Verification Commands

```bash
# Check VPC
aws ec2 describe-vpcs --vpc-ids $(terraform output -raw vpc_id)

# Check ECS cluster
aws ecs describe-clusters --clusters $(terraform output -raw ecs_cluster_name)

# Check RDS
aws rds describe-db-instances --db-instance-identifier $(terraform output -raw rds_identifier)

# Check Redis
aws elasticache describe-cache-clusters --cache-cluster-id $(terraform output -raw redis_cluster_id)

# Check ALB
aws elbv2 describe-load-balancers --load-balancer-arns $(terraform output -raw alb_arn)
```

## 💰 Cost Estimation

### Monthly Costs (us-east-1)
- **ECS Fargate**: $0 (no running tasks yet)
- **RDS db.t3.micro**: ~$13/month
- **ElastiCache t3.micro**: ~$12/month
- **ALB**: ~$16/month
- **NAT Gateway**: ~$32/month
- **Data Transfer**: ~$5/month
- **Total**: ~$78/month

## 🚨 Common Issues và Solutions

### 1. Terraform State Issues
```bash
# Remove problematic resource
terraform state rm aws_instance.example

# Import existing resource
terraform import aws_instance.example i-1234567890abcdef0
```

### 2. Security Group Dependencies
```bash
# Plan with target
terraform plan -target=aws_security_group.ecs_tasks

# Apply specific resources
terraform apply -target=aws_security_group.ecs_tasks
```

### 3. RDS Subnet Group Issues
```bash
# Check subnet group
aws rds describe-db-subnet-groups --db-subnet-group-name myproject-subnet-group
```

## 🚀 Chuẩn Bị Cho Phase 3

✅ **Infrastructure Ready** - All AWS resources deployed
✅ **Network Configured** - VPC, subnets, security groups
✅ **Database Running** - PostgreSQL accessible
✅ **Cache Available** - Redis cluster active
✅ **Load Balancer** - ALB ready for services
✅ **ECS Cluster** - Ready for task definitions

## 📝 Next Steps

1. **Phase 3**: Tạo Django microservices structure
2. **Database Migration**: Setup database schemas
3. **Service Configuration**: Environment variables
4. **Container Preparation**: Dockerfile creation

---

**Phase 2 Status**: ✅ **COMPLETED**
**Duration**: ~3 hours  
**Next Phase**: Phase 3 - Tạo Django Microservices Structure 