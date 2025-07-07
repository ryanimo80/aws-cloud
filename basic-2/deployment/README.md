# Phase 4: ECS Deployment Guide

## Tổng quan

Phase 4 triển khai **ECS Task Definitions** và **ECS Services** cho toàn bộ Django microservices trên AWS Fargate. Bao gồm:

- ✅ ECS Task Definitions cho 5 microservices
- ✅ ECS Services với Auto Scaling
- ✅ Service Discovery (AWS Cloud Map)
- ✅ Application Load Balancer integration
- ✅ Deployment automation scripts
- ✅ Health checking và monitoring

## Kiến trúc ECS

```
┌─────────────────────────────────────────────────────────────┐
│                     Application Load Balancer               │
│                    (Path-based routing)                     │
└─────────────────────────────────────────────────────────────┘
                                │
                    ┌───────────┼───────────┐
                    │           │           │
            ┌───────▼───┐   ┌───▼───┐   ┌───▼───┐
            │    ECS    │   │  ECS  │   │  ECS  │
            │  Service  │   │Service│   │Service│
            │           │   │       │   │       │
            └───────────┘   └───────┘   └───────┘
                    │           │           │
            ┌───────▼───┐   ┌───▼───┐   ┌───▼───┐
            │    ECS    │   │  ECS  │   │  ECS  │
            │   Tasks   │   │ Tasks │   │ Tasks │
            │ (Fargate) │   │(Fargate)│ │(Fargate)│
            └───────────┘   └───────┘   └───────┘
                    │           │           │
            ┌───────▼───────────▼───────────▼───┐
            │      Service Discovery Network     │
            │        (AWS Cloud Map)             │
            └───────────────────────────────────┘
```

## Cấu trúc Files

```
deployment/
├── deploy-all.sh       # Script chính deploy toàn bộ hệ thống
├── push-to-ecr.sh      # Build và push Docker images
├── deploy-services.sh  # Deploy ECS services
├── health-check.sh     # Kiểm tra health status
└── README.md          # Hướng dẫn này

terraform/
├── ecs-tasks.tf       # ECS Task Definitions
├── ecs-services.tf    # ECS Services & Auto Scaling
└── outputs.tf         # Updated outputs cho deployment
```

## Trước khi Deploy

### 1. Chuẩn bị Environment Variables

```bash
# Thiết lập AWS credentials
export AWS_ACCOUNT_ID=123456789012
export AWS_REGION=us-east-1

# Kiểm tra AWS CLI
aws sts get-caller-identity
```

### 2. Kiểm tra Dependencies

```bash
# Required tools
docker --version
terraform --version
aws --version
jq --version

# Make scripts executable
chmod +x deployment/*.sh
```

### 3. Chuẩn bị Docker Images

Đảm bảo các Dockerfile và microservices code đã sẵn sàng:

```bash
# Kiểm tra structure
ls -la microservices/
├── api-gateway/
├── user-service/
├── product-service/
├── order-service/
└── notification-service/
```

## Deployment Options

### Option 1: Full Deployment (Recommended)

Deploy toàn bộ hệ thống với 1 command:

```bash
# Deploy everything
./deployment/deploy-all.sh
```

Quá trình này sẽ:
1. 🏗️ Deploy infrastructure (Terraform)
2. 🐳 Build & push containers (Docker + ECR)
3. 🚀 Deploy services (ECS)
4. 🔍 Run health checks
5. 📊 Generate status report

### Option 2: Step-by-step Deployment

#### Step 1: Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
cd ..
```

#### Step 2: Container Images
```bash
./deployment/push-to-ecr.sh
```

#### Step 3: ECS Services
```bash
./deployment/deploy-services.sh
```

#### Step 4: Health Check
```bash
./deployment/health-check.sh
```

## ECS Services Configuration

### Service Specifications

| Service | Port | CPU | Memory | Min | Max | Health Check |
|---------|------|-----|--------|-----|-----|--------------|
| API Gateway | 8000 | 256 | 512MB | 1 | 10 | `/health/` |
| User Service | 8001 | 256 | 512MB | 1 | 10 | `/health/` |
| Product Service | 8002 | 256 | 512MB | 1 | 10 | `/health/` |
| Order Service | 8003 | 256 | 512MB | 1 | 10 | `/health/` |
| Notification Service | 8004 | 256 | 512MB | 1 | 10 | `/health/` |

### Service Discovery

Services được tự động đăng ký với AWS Cloud Map:

```
api-gateway.django-microservices.local:8000
user-service.django-microservices.local:8001
product-service.django-microservices.local:8002
order-service.django-microservices.local:8003
notification-service.django-microservices.local:8004
```

### Auto Scaling

- **Scaling Policy**: Target CPU 70%
- **Scale Up**: Tăng task khi CPU > 70%
- **Scale Down**: Giảm task khi CPU < 70%
- **Min Capacity**: 1 task
- **Max Capacity**: 10 tasks

## Monitoring & Management

### Health Checks

```bash
# Kiểm tra tất cả services
./deployment/health-check.sh

# Kiểm tra specific service
aws ecs describe-services --cluster django-microservices-cluster --services django-microservices-api-gateway
```

### View Logs

```bash
# CloudWatch Logs
aws logs tail /ecs/django-microservices/api-gateway --follow

# Specific service logs
aws logs describe-log-groups --log-group-name-prefix /ecs/django-microservices/
```

### Service Management

```bash
# Scale service
aws ecs update-service --cluster django-microservices-cluster --service django-microservices-api-gateway --desired-count 2

# Update service với new image
aws ecs update-service --cluster django-microservices-cluster --service django-microservices-api-gateway --force-new-deployment

# Stop service
aws ecs update-service --cluster django-microservices-cluster --service django-microservices-api-gateway --desired-count 0
```

## Service URLs

Sau khi deploy thành công:

```
🌐 Load Balancer:    http://your-alb-dns-name
🚪 API Gateway:      http://your-alb-dns-name/
👥 User Service:     http://your-alb-dns-name/users/
🛍️  Product Service:  http://your-alb-dns-name/products/
📦 Order Service:    http://your-alb-dns-name/orders/
🔔 Notification:     http://your-alb-dns-name/notifications/
```

## Cost Optimization

### Resource Usage

- **CPU**: 256 vCPU per service (5 services = 1,280 vCPU)
- **Memory**: 512MB per service (5 services = 2.5GB)
- **Networking**: Private subnets (no public IP)

### Cost Estimate

```
Base Infrastructure: ~$50/month
  - VPC, Subnets, Security Groups: Free
  - NAT Gateway: $32/month
  - ALB: $18/month

ECS Fargate: ~$26/month
  - 5 services × 256 vCPU × 512MB
  - $0.04048/vCPU-hour + $0.004445/GB-hour
  - ~$1.10/hour × 24 hours = $26.4/day

Database: ~$13/month
  - RDS db.t3.micro: $13/month

Redis: ~$11/month
  - ElastiCache cache.t3.micro: $11/month

Total: ~$100/month
```

## Troubleshooting

### Common Issues

#### 1. Service không start

```bash
# Kiểm tra task definition
aws ecs describe-task-definition --task-definition django-microservices-api-gateway

# Kiểm tra service events
aws ecs describe-services --cluster django-microservices-cluster --services django-microservices-api-gateway
```

#### 2. Health check failed

```bash
# Kiểm tra target group
aws elbv2 describe-target-health --target-group-arn your-target-group-arn

# Test health endpoint
curl -I http://your-alb-dns/health/
```

#### 3. Container không thể pull image

```bash
# Kiểm tra ECR repository
aws ecr describe-repositories --repository-names django-microservices-api-gateway

# Kiểm tra ECS execution role
aws iam get-role --role-name django-microservices-ecs-execution-role
```

#### 4. Service communication issues

```bash
# Kiểm tra service discovery
aws servicediscovery list-services --filters Name=NAMESPACE_ID,Values=your-namespace-id

# Kiểm tra security groups
aws ec2 describe-security-groups --group-ids sg-xxxxxxxx
```

## Production Considerations

### Security

- [ ] Enable WAF cho ALB
- [ ] Implement proper IAM roles
- [ ] Enable VPC Flow Logs
- [ ] Configure SSL/TLS certificates

### Performance

- [ ] Configure CloudWatch Container Insights
- [ ] Set up proper logging aggregation
- [ ] Configure distributed tracing (X-Ray)
- [ ] Implement circuit breakers

### High Availability

- [ ] Multi-AZ deployment
- [ ] Database read replicas
- [ ] Redis cluster mode
- [ ] Blue/Green deployment strategy

## Next Steps

Sau khi hoàn thành Phase 4:

1. **Phase 5**: CI/CD Pipeline (GitHub Actions)
2. **Phase 6**: Monitoring & Alerting (CloudWatch, Grafana)
3. **Phase 7**: Security & Compliance (WAF, Security Groups)
4. **Phase 8**: Performance Optimization & Testing

## Support

Nếu gặp vấn đề:

1. Kiểm tra logs: `./deployment/health-check.sh`
2. Xem events: `aws ecs describe-services ...`
3. Kiểm tra CloudWatch metrics
4. Verify security groups và networking

---

**Phase 4 Status**: ✅ **COMPLETED**

**Services Deployed**: 5/5 microservices running on ECS Fargate
**Auto Scaling**: Enabled với CPU-based scaling
**Service Discovery**: Configured với AWS Cloud Map
**Health Checks**: Automated monitoring setup 