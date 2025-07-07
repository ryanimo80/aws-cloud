# Django Microservices Architecture

This directory contains the complete microservices architecture for the Django application, designed to run on AWS ECS Fargate.

## 🏗️ Architecture Overview

The system consists of 5 microservices:

1. **API Gateway** (Port 8000) - Entry point, routing, authentication
2. **User Service** (Port 8001) - User management, authentication
3. **Product Service** (Port 8002) - Product catalog, inventory
4. **Order Service** (Port 8003) - Order processing, payments
5. **Notification Service** (Port 8004) - Email, SMS, push notifications

## 📁 Project Structure

```
microservices/
├── shared/
│   └── requirements.txt          # Common dependencies
├── api-gateway/
│   ├── Dockerfile
│   └── requirements.txt
├── user-service/
│   ├── Dockerfile
│   └── requirements.txt
├── product-service/
│   ├── Dockerfile
│   └── requirements.txt
├── order-service/
│   ├── Dockerfile
│   └── requirements.txt
├── notification-service/
│   ├── Dockerfile
│   └── requirements.txt
└── README.md                     # This file
```

## 🚀 Quick Start

### Local Development

1. **Setup Environment**
   ```bash
   cp env.example .env
   # Edit .env with your configuration
   ```

2. **Build All Services**
   ```bash
   chmod +x build.sh
   ./build.sh
   ```

3. **Start All Services**
   ```bash
   docker-compose up
   ```

4. **Access Services**
   - API Gateway: http://localhost:8000
   - User Service: http://localhost:8001
   - Product Service: http://localhost:8002
   - Order Service: http://localhost:8003
   - Notification Service: http://localhost:8004
   - Nginx Load Balancer: http://localhost

### Health Checks

```bash
# Check all services
curl http://localhost:8000/health/
curl http://localhost:8001/health/
curl http://localhost:8002/health/
curl http://localhost:8003/health/
curl http://localhost:8004/health/
```

## 🛠️ Service Details

### API Gateway (Port 8000)
- **Purpose**: Entry point for all client requests
- **Features**:
  - Request routing to appropriate services
  - Authentication and authorization
  - Rate limiting
  - Request/response transformation
  - Load balancing
- **Key Dependencies**: FastAPI, Django, Redis, JWT

### User Service (Port 8001)
- **Purpose**: User management and authentication
- **Features**:
  - User registration and login
  - Profile management
  - JWT token management
  - Social authentication
  - Password reset
- **Key Dependencies**: Django, PostgreSQL, Redis, JWT

### Product Service (Port 8002)
- **Purpose**: Product catalog and inventory
- **Features**:
  - Product CRUD operations
  - Category management
  - Search and filtering
  - Inventory tracking
  - Image management
- **Key Dependencies**: Django, PostgreSQL, Elasticsearch, S3

### Order Service (Port 8003)
- **Purpose**: Order processing and payments
- **Features**:
  - Shopping cart management
  - Order creation and tracking
  - Payment processing (Stripe, PayPal)
  - Order status updates
  - Invoice generation
- **Key Dependencies**: Django, PostgreSQL, Stripe, PayPal

### Notification Service (Port 8004)
- **Purpose**: Multi-channel notifications
- **Features**:
  - Email notifications
  - SMS notifications
  - Push notifications
  - Template management
  - Delivery tracking
- **Key Dependencies**: Django, SendGrid, Twilio, FCM

## 🔧 Configuration

### Environment Variables

Copy `env.example` to `.env` and configure:

```bash
# Database
DATABASE_URL=postgresql://django:ChangeMe123!@postgres:5432/djangodb
REDIS_URL=redis://redis:6379/0

# Services
USER_SERVICE_URL=http://user-service:8001
PRODUCT_SERVICE_URL=http://product-service:8002
ORDER_SERVICE_URL=http://order-service:8003
NOTIFICATION_SERVICE_URL=http://notification-service:8004

# External Services
SENDGRID_API_KEY=your-sendgrid-api-key
STRIPE_SECRET_KEY=your-stripe-secret-key
TWILIO_AUTH_TOKEN=your-twilio-auth-token
```

### Docker Compose Services

- **postgres**: PostgreSQL database
- **redis**: Redis cache and message broker
- **api-gateway**: API Gateway service
- **user-service**: User management service
- **product-service**: Product catalog service
- **order-service**: Order processing service
- **notification-service**: Notification service
- **nginx**: Load balancer (optional)

## 🎯 Service Communication

### Inter-Service Communication
- **HTTP/REST**: Synchronous communication
- **Redis Pub/Sub**: Asynchronous messaging
- **Service Discovery**: Environment-based URLs

### API Endpoints Structure

```
# API Gateway
GET  /                          # Health check
POST /auth/login               # Authentication
GET  /auth/refresh             # Token refresh

# User Service
GET  /users/                   # List users
POST /users/                   # Create user
GET  /users/{id}/              # Get user
PUT  /users/{id}/              # Update user

# Product Service
GET  /products/                # List products
POST /products/                # Create product
GET  /products/{id}/           # Get product
GET  /categories/              # List categories

# Order Service
GET  /orders/                  # List orders
POST /orders/                  # Create order
GET  /cart/                    # Get cart
POST /cart/items/              # Add to cart

# Notification Service
POST /notifications/email/     # Send email
POST /notifications/sms/       # Send SMS
GET  /notifications/history/   # Get history
```

## 📊 Monitoring & Logging

### Health Checks
Each service exposes a `/health/` endpoint for monitoring:
- Database connectivity
- Redis connectivity
- External service availability

### Logging
- **Local**: Docker logs via `docker-compose logs`
- **Production**: CloudWatch logs (configured in ECS)

### Metrics
- **Prometheus**: Service metrics
- **Django Debug Toolbar**: Development debugging

## 🔐 Security

### Authentication & Authorization
- **JWT Tokens**: Stateless authentication
- **Service-to-Service**: Internal API keys
- **Rate Limiting**: Request throttling

### Data Protection
- **Database Encryption**: TLS connections
- **Secrets Management**: Environment variables
- **CORS**: Cross-origin request handling

## 🏃‍♂️ Development Workflow

### 1. Local Development
```bash
# Start all services
docker-compose up

# Restart specific service
docker-compose restart user-service

# View logs
docker-compose logs -f api-gateway

# Execute commands
docker-compose exec user-service python manage.py migrate
```

### 2. Testing
```bash
# Run tests for specific service
docker-compose exec user-service python manage.py test

# Run all tests
./run_tests.sh
```

### 3. Building for Production
```bash
# Build all images
./build.sh

# Tag for ECR
export AWS_ACCOUNT_ID=123456789012
export AWS_REGION=us-east-1
./build.sh
```

## 🚢 Deployment

### AWS ECS Fargate
1. **Infrastructure**: Deploy using Terraform (Phase 2)
2. **Images**: Push to ECR repositories
3. **Services**: Deploy ECS services and task definitions
4. **Load Balancer**: Configure ALB routing

### CI/CD Pipeline
- **Build**: Docker image builds
- **Test**: Automated testing
- **Deploy**: ECS service updates
- **Monitor**: Health checks and rollback

## 📝 Next Steps

After completing Phase 3:

1. **Phase 4**: Containerization - Build and push Docker images
2. **Phase 5**: ECS Deployment - Deploy services to AWS
3. **Phase 6**: CI/CD Pipeline - Automate deployments
4. **Phase 7**: Monitoring & Security - Add observability
5. **Phase 8**: Testing & Optimization - Performance tuning

## 🆘 Troubleshooting

### Common Issues

1. **Port Conflicts**
   ```bash
   # Check if ports are in use
   lsof -i :8000
   
   # Stop conflicting services
   docker-compose down
   ```

2. **Database Connection**
   ```bash
   # Check PostgreSQL
   docker-compose exec postgres psql -U django -d djangodb
   
   # Check Redis
   docker-compose exec redis redis-cli ping
   ```

3. **Service Communication**
   ```bash
   # Test service connectivity
   docker-compose exec api-gateway curl http://user-service:8001/health/
   ```

### Debug Commands

```bash
# Check service status
docker-compose ps

# View service logs
docker-compose logs <service-name>

# Execute shell in service
docker-compose exec <service-name> /bin/bash

# Check Docker networks
docker network ls
docker network inspect basic-2_default
```

## 📚 Resources

- [Django Documentation](https://docs.djangoproject.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Microservices Patterns](https://microservices.io/)

## 🤝 Contributing

1. Follow the existing code structure
2. Update documentation for any changes
3. Add tests for new features
4. Ensure all services pass health checks
5. Update environment variables as needed

---

**Ready for Phase 4: Containerization** 🚀 