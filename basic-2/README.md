# Django Microservices on AWS ECS Fargate

## 🚀 Tổng quan

Dự án Django Microservices được triển khai trên AWS ECS Fargate, bao gồm:

- **API Gateway**: Central entry point, authentication, rate limiting
- **User Service**: User management, authentication, profiles
- **Product Service**: Product catalog, inventory, search
- **Order Service**: Order processing, payments, tracking
- **Notification Service**: Email, SMS, push notifications

## 📋 Prerequisites

### Development Environment
- Python 3.11+
- Docker & Docker Compose
- AWS CLI v2
- Terraform 1.5+
- Git

### AWS Account Requirements
- AWS Account với appropriate permissions
- ECR repositories
- VPC và networking setup
- RDS PostgreSQL instance
- ElastiCache Redis cluster

## 🔧 Local Development Setup

### 1. Clone Repository
```bash
git clone <repository-url>
cd django-microservices
```

### 2. Environment Setup
```bash
# Copy environment template
cp .env.example .env

# Edit environment variables
nano .env
```

### 3. Required Environment Variables
```env
# Database
DB_NAME=djangodb
DB_USER=django
DB_PASSWORD=your_password
DB_HOST=localhost
DB_PORT=5432

# Redis
REDIS_URL=redis://localhost:6379/1

# Django
SECRET_KEY=your-secret-key
DEBUG=True
ALLOWED_HOSTS=localhost,127.0.0.1

# AWS (for production)
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=us-east-1

# Microservices URLs
USER_SERVICE_URL=http://user-service:8001
PRODUCT_SERVICE_URL=http://product-service:8002
ORDER_SERVICE_URL=http://order-service:8003
NOTIFICATION_SERVICE_URL=http://notification-service:8004
```

### 4. Start Development Environment
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### 5. Database Setup
```bash
# Run migrations
docker-compose exec api-gateway python manage.py migrate
docker-compose exec user-service python manage.py migrate
docker-compose exec product-service python manage.py migrate
docker-compose exec order-service python manage.py migrate

# Create superuser
docker-compose exec user-service python manage.py createsuperuser
```

## 🏗️ Project Structure

```
django-microservices/
├── microservices/
│   ├── shared/                 # Shared code and configurations
│   │   ├── requirements.txt
│   │   ├── settings.py
│   │   └── utils.py
│   ├── api-gateway/           # API Gateway service
│   │   ├── Dockerfile
│   │   ├── settings.py
│   │   ├── urls.py
│   │   └── apps/
│   ├── user-service/          # User management service
│   │   ├── Dockerfile
│   │   ├── settings.py
│   │   └── apps/
│   ├── product-service/       # Product catalog service
│   │   ├── Dockerfile
│   │   ├── settings.py
│   │   └── apps/
│   ├── order-service/         # Order processing service
│   │   ├── Dockerfile
│   │   ├── settings.py
│   │   └── apps/
│   └── notification-service/  # Notification service
│       ├── Dockerfile
│       ├── settings.py
│       └── apps/
├── terraform/                 # Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── modules/
├── .github/workflows/         # CI/CD pipelines
├── docker-compose.yml         # Local development
├── docker-compose.override.yml
└── docs/                      # Documentation
```

## 🐳 Docker Commands

### Build Services
```bash
# Build all services
docker-compose build

# Build specific service
docker-compose build api-gateway

# Build with no cache
docker-compose build --no-cache
```

### Service Management
```bash
# Start specific service
docker-compose up api-gateway

# Scale service
docker-compose up --scale api-gateway=3

# Restart service
docker-compose restart api-gateway

# View service logs
docker-compose logs -f api-gateway
```

### Database Operations
```bash
# Database shell
docker-compose exec user-service python manage.py dbshell

# Django shell
docker-compose exec user-service python manage.py shell

# Run custom management command
docker-compose exec user-service python manage.py custom_command
```

## 🔍 API Testing

### Health Checks
```bash
# Check all services
curl http://localhost:8000/health/     # API Gateway
curl http://localhost:8001/health/     # User Service
curl http://localhost:8002/health/     # Product Service
curl http://localhost:8003/health/     # Order Service
curl http://localhost:8004/health/     # Notification Service
```

### API Documentation
- **Swagger UI**: http://localhost:8000/docs/
- **ReDoc**: http://localhost:8000/redoc/
- **OpenAPI Schema**: http://localhost:8000/schema/

### Authentication
```bash
# Login to get JWT token
curl -X POST http://localhost:8000/auth/login/ \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "password"}'

# Use token for authenticated requests
curl -X GET http://localhost:8000/users/profile/ \
  -H "Authorization: Bearer <your-jwt-token>"
```

## 🧪 Testing

### Run Tests
```bash
# Run all tests
docker-compose exec api-gateway python manage.py test

# Run specific app tests
docker-compose exec user-service python manage.py test users

# Run with coverage
docker-compose exec api-gateway coverage run --source='.' manage.py test
docker-compose exec api-gateway coverage report
```

### Load Testing
```bash
# Install k6
brew install k6

# Run load test
k6 run tests/load-test.js
```

## 🚀 Deployment

### Development Deployment
```bash
# Deploy to development environment
./scripts/deploy-dev.sh
```

### Production Deployment
```bash
# Deploy to production
./scripts/deploy-prod.sh

# Rollback if needed
./scripts/rollback.sh
```

### Infrastructure Deployment
```bash
# Initialize Terraform
cd terraform
terraform init

# Plan infrastructure changes
terraform plan

# Apply changes
terraform apply
```

## 📊 Monitoring

### CloudWatch Dashboards
- **Application Metrics**: CPU, Memory, Response Times
- **Business Metrics**: User registrations, Orders, Revenue
- **Infrastructure Metrics**: ECS tasks, RDS connections

### Logs
```bash
# View application logs
aws logs tail /ecs/django-microservices --follow

# View specific service logs
aws logs tail /ecs/django-microservices/api-gateway --follow
```

### Alerts
- High CPU/Memory utilization
- Database connection failures
- High error rates
- Slow response times

## 🔧 Troubleshooting

### Common Issues

#### Container Won't Start
```bash
# Check container logs
docker-compose logs api-gateway

# Check container status
docker-compose ps

# Rebuild container
docker-compose build --no-cache api-gateway
```

#### Database Connection Issues
```bash
# Check database connectivity
docker-compose exec api-gateway python manage.py check --database default

# Test database connection
docker-compose exec db psql -U django -d djangodb
```

#### Service Communication Issues
```bash
# Check service discovery
docker-compose exec api-gateway nslookup user-service

# Test service connectivity
docker-compose exec api-gateway curl http://user-service:8001/health/
```

## 📚 Documentation

- [Architecture Overview](ARCHITECTURE.md)
- [Deployment Guide](DEPLOYMENT.md)
- [API Design](API_DESIGN.md)
- [Security Guidelines](docs/SECURITY.md)
- [Operations Manual](docs/OPERATIONS.md)

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: Create GitHub issue
- **Documentation**: Check docs/ directory
- **Slack**: #django-microservices
- **Email**: support@example.com

## 🔗 Useful Links

- [Django Documentation](https://docs.djangoproject.com/)
- [Django REST Framework](https://www.django-rest-framework.org/)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Terraform Documentation](https://www.terraform.io/docs/)
- [Docker Documentation](https://docs.docker.com/) 