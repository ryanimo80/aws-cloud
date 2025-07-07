# Django Microservices Deployment Guide

## 🚀 Tổng quan Deployment

Hướng dẫn này mô tả quy trình deployment Django microservices lên AWS ECS Fargate từ development đến production.

## 📋 Prerequisites

### AWS Account Setup
- AWS Account với appropriate IAM permissions
- AWS CLI v2 configured
- ECR access cho container registry
- VPC và networking đã được setup

### Tools Required
- Docker & Docker Compose
- Terraform >= 1.5
- GitHub Actions (cho CI/CD)
- AWS CLI v2

## 🏗️ Infrastructure Setup

### 1. Terraform Infrastructure Deployment

#### Initialize Terraform
```bash
cd terraform
terraform init
```

#### Review và Plan Infrastructure
```bash
# Review planned changes
terraform plan

# Apply infrastructure
terraform apply
```

#### Key Infrastructure Components
- **VPC**: Multi-AZ setup với public/private subnets
- **RDS**: PostgreSQL Multi-AZ database
- **ElastiCache**: Redis cluster
- **ECS**: Fargate cluster
- **ALB**: Application Load Balancer
- **ECR**: Container repositories

### 2. Database Setup

#### RDS PostgreSQL Configuration
```bash
# Connect to RDS instance
aws rds describe-db-instances --db-instance-identifier django-microservices-postgres

# Create database schemas
psql -h <rds-endpoint> -U django -d djangodb
```

#### Database Migration
```bash
# Run migrations for each service
python manage.py migrate --settings=user_service.settings
python manage.py migrate --settings=product_service.settings
python manage.py migrate --settings=order_service.settings
```

## 🐳 Container Deployment

### 1. Build Docker Images

#### Build All Services
```bash
# Build all microservices
./scripts/build-all.sh

# Or build individually
docker build -t api-gateway ./microservices/api-gateway
docker build -t user-service ./microservices/user-service
docker build -t product-service ./microservices/product-service
docker build -t order-service ./microservices/order-service
docker build -t notification-service ./microservices/notification-service
```

#### Tag Images for ECR
```bash
# Get ECR login token
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Tag images
docker tag api-gateway:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/django-microservices-api-gateway:latest
docker tag user-service:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/django-microservices-user-service:latest
docker tag product-service:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/django-microservices-product-service:latest
docker tag order-service:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/django-microservices-order-service:latest
docker tag notification-service:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/django-microservices-notification-service:latest
```

#### Push Images to ECR
```bash
# Push all images
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/django-microservices-api-gateway:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/django-microservices-user-service:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/django-microservices-product-service:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/django-microservices-order-service:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/django-microservices-notification-service:latest
```

### 2. ECS Task Definitions

#### Create Task Definition Files
```json
{
  "family": "django-microservices-api-gateway",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "executionRoleArn": "arn:aws:iam::<account-id>:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::<account-id>:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "api-gateway",
      "image": "<account-id>.dkr.ecr.us-east-1.amazonaws.com/django-microservices-api-gateway:latest",
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "DJANGO_SETTINGS_MODULE",
          "value": "settings"
        }
      ],
      "secrets": [
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:us-east-1:<account-id>:secret:django-microservices-db-password"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/django-microservices",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "api-gateway"
        }
      },
      "healthCheck": {
        "command": ["CMD-SHELL", "curl -f http://localhost:8000/health/ || exit 1"],
        "interval": 30,
        "timeout": 5,
        "retries": 3
      }
    }
  ]
}
```

#### Register Task Definitions
```bash
# Register task definitions
aws ecs register-task-definition --cli-input-json file://task-definitions/api-gateway.json
aws ecs register-task-definition --cli-input-json file://task-definitions/user-service.json
aws ecs register-task-definition --cli-input-json file://task-definitions/product-service.json
aws ecs register-task-definition --cli-input-json file://task-definitions/order-service.json
aws ecs register-task-definition --cli-input-json file://task-definitions/notification-service.json
```

### 3. ECS Service Creation

#### Create ECS Services
```bash
# Create services
aws ecs create-service \
  --cluster django-microservices-cluster \
  --service-name api-gateway \
  --task-definition django-microservices-api-gateway:1 \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-12345,subnet-67890],securityGroups=[sg-12345],assignPublicIp=DISABLED}" \
  --load-balancers "targetGroupArn=arn:aws:elasticloadbalancing:us-east-1:<account-id>:targetgroup/django-microservices-api-gateway-tg,containerName=api-gateway,containerPort=8000"
```

#### Configure Auto Scaling
```bash
# Register scalable target
aws application-autoscaling register-scalable-target \
  --service-namespace ecs \
  --resource-id service/django-microservices-cluster/api-gateway \
  --scalable-dimension ecs:service:DesiredCount \
  --min-capacity 2 \
  --max-capacity 10

# Create scaling policy
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/django-microservices-cluster/api-gateway \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name api-gateway-cpu-scaling \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration file://scaling-policy.json
```

## 🔄 CI/CD Pipeline

### 1. GitHub Actions Workflow

#### Main Workflow File (`.github/workflows/deploy.yml`)
```yaml
name: Deploy to AWS ECS

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  AWS_REGION: us-east-1
  ECR_REGISTRY: ${{ secrets.AWS_ACCOUNT_ID }}.dkr.ecr.us-east-1.amazonaws.com
  ECS_CLUSTER: django-microservices-cluster

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r microservices/shared/requirements.txt
      
      - name: Run tests
        run: |
          python -m pytest tests/

  build-and-deploy:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    
    strategy:
      matrix:
        service: [api-gateway, user-service, product-service, order-service, notification-service]
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      
      - name: Build, tag, and push image to Amazon ECR
        env:
          ECR_REPOSITORY: django-microservices-${{ matrix.service }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG ./microservices/${{ matrix.service }}
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          docker tag $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG $ECR_REGISTRY/$ECR_REPOSITORY:latest
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
      
      - name: Update ECS service
        env:
          SERVICE_NAME: ${{ matrix.service }}
        run: |
          aws ecs update-service \
            --cluster $ECS_CLUSTER \
            --service $SERVICE_NAME \
            --force-new-deployment
```

### 2. Environment-Specific Deployments

#### Development Environment
```bash
# Deploy to development
./scripts/deploy-dev.sh

# Environment variables for dev
export ENVIRONMENT=dev
export DB_HOST=dev-db-endpoint
export REDIS_URL=redis://dev-redis-endpoint:6379
```

#### Staging Environment
```bash
# Deploy to staging
./scripts/deploy-staging.sh

# Environment variables for staging
export ENVIRONMENT=staging
export DB_HOST=staging-db-endpoint
export REDIS_URL=redis://staging-redis-endpoint:6379
```

#### Production Environment
```bash
# Deploy to production
./scripts/deploy-prod.sh

# Environment variables for production
export ENVIRONMENT=prod
export DB_HOST=prod-db-endpoint
export REDIS_URL=redis://prod-redis-endpoint:6379
```

## 🔒 Security Configuration

### 1. Secrets Management

#### AWS Secrets Manager
```bash
# Create database password secret
aws secretsmanager create-secret \
  --name django-microservices-db-password \
  --description "Database password for Django microservices" \
  --secret-string "your-secure-password"

# Create JWT secret
aws secretsmanager create-secret \
  --name django-microservices-jwt-secret \
  --description "JWT secret key for Django microservices" \
  --secret-string "your-jwt-secret-key"
```

#### Parameter Store
```bash
# Store non-sensitive configuration
aws ssm put-parameter \
  --name "/django-microservices/db-host" \
  --value "your-db-endpoint" \
  --type "String"

aws ssm put-parameter \
  --name "/django-microservices/redis-url" \
  --value "redis://your-redis-endpoint:6379" \
  --type "String"
```

### 2. IAM Roles và Policies

#### ECS Task Execution Role
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "secretsmanager:GetSecretValue",
        "ssm:GetParameter",
        "ssm:GetParameters"
      ],
      "Resource": "*"
    }
  ]
}
```

#### ECS Task Role
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sns:Publish"
      ],
      "Resource": "*"
    }
  ]
}
```

## 📊 Monitoring và Logging

### 1. CloudWatch Setup

#### Log Groups
```bash
# Create log groups
aws logs create-log-group --log-group-name /ecs/django-microservices
aws logs create-log-group --log-group-name /ecs/django-microservices/api-gateway
aws logs create-log-group --log-group-name /ecs/django-microservices/user-service
aws logs create-log-group --log-group-name /ecs/django-microservices/product-service
aws logs create-log-group --log-group-name /ecs/django-microservices/order-service
aws logs create-log-group --log-group-name /ecs/django-microservices/notification-service
```

#### CloudWatch Alarms
```bash
# High CPU alarm
aws cloudwatch put-metric-alarm \
  --alarm-name "ECS-HighCPU" \
  --alarm-description "High CPU utilization" \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

### 2. Application Monitoring

#### Health Check Endpoints
```python
# Django health check view
from django.http import JsonResponse
from django.db import connection

def health_check(request):
    try:
        # Check database connectivity
        cursor = connection.cursor()
        cursor.execute("SELECT 1")
        
        # Check Redis connectivity
        from django.core.cache import cache
        cache.set('health_check', 'ok', 30)
        
        return JsonResponse({
            'status': 'healthy',
            'database': 'ok',
            'cache': 'ok',
            'timestamp': timezone.now().isoformat()
        })
    except Exception as e:
        return JsonResponse({
            'status': 'unhealthy',
            'error': str(e)
        }, status=500)
```

## 🔄 Blue-Green Deployment

### 1. Blue-Green Strategy

#### Deployment Script
```bash
#!/bin/bash
# Blue-Green deployment script

SERVICE_NAME=$1
NEW_TASK_DEFINITION_ARN=$2
CLUSTER_NAME="django-microservices-cluster"

# Get current service configuration
CURRENT_SERVICE=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --query 'services[0]')

# Create new service with updated task definition
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --task-definition $NEW_TASK_DEFINITION_ARN

# Wait for deployment to complete
aws ecs wait services-stable \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME

# Verify health checks
./scripts/verify-health.sh $SERVICE_NAME

if [ $? -eq 0 ]; then
  echo "Deployment successful"
else
  echo "Deployment failed, rolling back..."
  ./scripts/rollback.sh $SERVICE_NAME
fi
```

### 2. Rollback Procedure

#### Rollback Script
```bash
#!/bin/bash
# Rollback script

SERVICE_NAME=$1
CLUSTER_NAME="django-microservices-cluster"

# Get previous task definition
PREVIOUS_TASK_DEF=$(aws ecs describe-services \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME \
  --query 'services[0].deployments[1].taskDefinition' \
  --output text)

# Rollback to previous version
aws ecs update-service \
  --cluster $CLUSTER_NAME \
  --service $SERVICE_NAME \
  --task-definition $PREVIOUS_TASK_DEF

# Wait for rollback to complete
aws ecs wait services-stable \
  --cluster $CLUSTER_NAME \
  --services $SERVICE_NAME

echo "Rollback completed"
```

## 🧪 Testing và Validation

### 1. Pre-deployment Tests

#### Integration Tests
```bash
# Run integration tests
python -m pytest tests/integration/

# Run load tests
k6 run tests/load-test.js
```

#### Database Migration Tests
```bash
# Test migrations
python manage.py migrate --dry-run --verbosity=2
```

### 2. Post-deployment Validation

#### Health Check Validation
```bash
# Check all services
./scripts/health-check-all.sh

# Check specific service
curl -f http://your-alb-dns/health/ || exit 1
```

#### Smoke Tests
```bash
# Run smoke tests
python -m pytest tests/smoke/
```

## 📝 Deployment Checklist

### Pre-deployment
- [ ] Code review completed
- [ ] Tests passing
- [ ] Database migrations reviewed
- [ ] Environment variables updated
- [ ] Secrets management verified
- [ ] Security review completed

### Deployment
- [ ] Infrastructure deployed
- [ ] Database migrated
- [ ] Images built và pushed
- [ ] ECS services updated
- [ ] Load balancer configured
- [ ] SSL certificates verified

### Post-deployment
- [ ] Health checks passing
- [ ] Monitoring setup
- [ ] Logs streaming
- [ ] Performance metrics normal
- [ ] Alerts configured
- [ ] Documentation updated

## 🚨 Troubleshooting

### Common Issues

#### Task Won't Start
```bash
# Check task definition
aws ecs describe-task-definition --task-definition your-task-definition

# Check service events
aws ecs describe-services --cluster your-cluster --services your-service

# Check container logs
aws logs tail /ecs/django-microservices/api-gateway --follow
```

#### High Memory Usage
```bash
# Check memory metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name MemoryUtilization \
  --dimensions Name=ServiceName,Value=api-gateway \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 300 \
  --statistics Average
```

#### Database Connection Issues
```bash
# Test database connectivity
aws rds describe-db-instances --db-instance-identifier your-db-instance

# Check security groups
aws ec2 describe-security-groups --group-ids sg-12345
```

## 📚 Additional Resources

- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Django Deployment Checklist](https://docs.djangoproject.com/en/4.2/howto/deployment/checklist/)
- [Docker Best Practices](https://docs.docker.com/develop/best-practices/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest) 