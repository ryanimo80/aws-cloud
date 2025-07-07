#!/bin/bash

# Build script for Django Microservices
# This script builds all Docker images for the microservices

set -e

echo "🚀 Building Django Microservices Docker Images..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Project name
PROJECT_NAME="django-microservices"

# Services to build
SERVICES=(
    "api-gateway"
    "user-service"
    "product-service"
    "order-service"
    "notification-service"
)

# Build each service
for service in "${SERVICES[@]}"; do
    print_status "Building $service..."
    
    if [ -d "microservices/$service" ]; then
        cd "microservices/$service"
        
        # Check if Dockerfile exists
        if [ ! -f "Dockerfile" ]; then
            print_error "Dockerfile not found in microservices/$service"
            cd ../..
            continue
        fi
        
        # Build the Docker image
        docker build -t "$PROJECT_NAME-$service:latest" . || {
            print_error "Failed to build $service"
            cd ../..
            continue
        }
        
        print_status "Successfully built $PROJECT_NAME-$service:latest"
        cd ../..
    else
        print_warning "Directory microservices/$service does not exist"
    fi
done

# Build completion message
print_status "Build process completed!"

# Show built images
print_status "Built images:"
docker images | grep "$PROJECT_NAME" || print_warning "No images found with prefix $PROJECT_NAME"

# Optional: Tag images for ECR if AWS_ACCOUNT_ID is set
if [ ! -z "$AWS_ACCOUNT_ID" ] && [ ! -z "$AWS_REGION" ]; then
    print_status "Tagging images for ECR..."
    
    for service in "${SERVICES[@]}"; do
        ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME-$service:latest"
        
        if docker image inspect "$PROJECT_NAME-$service:latest" > /dev/null 2>&1; then
            docker tag "$PROJECT_NAME-$service:latest" "$ECR_URI"
            print_status "Tagged $service for ECR: $ECR_URI"
        fi
    done
fi

# Usage information
echo ""
print_status "Usage:"
echo "  To run all services: docker-compose up"
echo "  To run specific service: docker-compose up <service-name>"
echo "  To run in background: docker-compose up -d"
echo "  To stop all services: docker-compose down"
echo ""
print_status "Available services:"
for service in "${SERVICES[@]}"; do
    echo "  - $service (http://localhost:800${service: -1})"
done

# Health check
echo ""
print_status "To check if services are running:"
echo "  curl http://localhost:8000/health/"  # API Gateway
echo "  curl http://localhost:8001/health/"  # User Service
echo "  curl http://localhost:8002/health/"  # Product Service
echo "  curl http://localhost:8003/health/"  # Order Service  
echo "  curl http://localhost:8004/health/"  # Notification Service

print_status "Build script completed successfully! 🎉" 