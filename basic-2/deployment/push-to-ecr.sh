#!/bin/bash

# Push Docker images to ECR
# This script builds and pushes all microservice images to AWS ECR

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_header() {
    echo -e "${BLUE}[DEPLOY]${NC} $1"
}

# Check required environment variables
if [ -z "$AWS_ACCOUNT_ID" ]; then
    print_error "AWS_ACCOUNT_ID environment variable is required"
    exit 1
fi

if [ -z "$AWS_REGION" ]; then
    print_error "AWS_REGION environment variable is required"
    exit 1
fi

# Configuration
PROJECT_NAME="django-microservices"
ECR_REGISTRY="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

# Services to build and push
SERVICES=(
    "api-gateway"
    "user-service" 
    "product-service"
    "order-service"
    "notification-service"
)

print_header "Starting ECR deployment for $PROJECT_NAME"
echo "Registry: $ECR_REGISTRY"
echo "Region: $AWS_REGION"
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed"
    exit 1
fi

# Login to ECR
print_status "Logging into Amazon ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY || {
    print_error "Failed to login to ECR"
    exit 1
}

print_status "Successfully logged into ECR"

# Build and push each service
for service in "${SERVICES[@]}"; do
    print_header "Processing $service..."
    
    # Check if service directory exists
    if [ ! -d "microservices/$service" ]; then
        print_warning "Directory microservices/$service does not exist, skipping..."
        continue
    fi
    
    cd "microservices/$service"
    
    # Check if Dockerfile exists
    if [ ! -f "Dockerfile" ]; then
        print_warning "Dockerfile not found in microservices/$service, skipping..."
        cd ../..
        continue
    fi
    
    # ECR repository URL
    ECR_REPO="$ECR_REGISTRY/$PROJECT_NAME-$service"
    
    print_status "Building Docker image for $service..."
    
    # Build the Docker image
    docker build -t "$PROJECT_NAME-$service:latest" . || {
        print_error "Failed to build $service"
        cd ../..
        continue
    }
    
    # Tag the image for ECR
    docker tag "$PROJECT_NAME-$service:latest" "$ECR_REPO:latest" || {
        print_error "Failed to tag $service for ECR"
        cd ../..
        continue
    }
    
    # Create ECR repository if it doesn't exist
    aws ecr describe-repositories --repository-names "$PROJECT_NAME-$service" --region $AWS_REGION > /dev/null 2>&1 || {
        print_status "Creating ECR repository for $service..."
        aws ecr create-repository --repository-name "$PROJECT_NAME-$service" --region $AWS_REGION > /dev/null || {
            print_error "Failed to create ECR repository for $service"
            cd ../..
            continue
        }
    }
    
    print_status "Pushing $service to ECR..."
    
    # Push the image to ECR
    docker push "$ECR_REPO:latest" || {
        print_error "Failed to push $service to ECR"
        cd ../..
        continue
    }
    
    print_status "Successfully pushed $service to ECR"
    
    # Tag with current timestamp
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    docker tag "$PROJECT_NAME-$service:latest" "$ECR_REPO:$TIMESTAMP"
    docker push "$ECR_REPO:$TIMESTAMP" || {
        print_warning "Failed to push timestamped tag for $service"
    }
    
    cd ../..
done

# Clean up local images to save space
print_status "Cleaning up local images..."
for service in "${SERVICES[@]}"; do
    ECR_REPO="$ECR_REGISTRY/$PROJECT_NAME-$service"
    
    # Remove local images
    docker rmi "$PROJECT_NAME-$service:latest" 2>/dev/null || true
    docker rmi "$ECR_REPO:latest" 2>/dev/null || true
done

# Show final status
print_header "ECR Push Summary"
echo ""

for service in "${SERVICES[@]}"; do
    ECR_REPO="$ECR_REGISTRY/$PROJECT_NAME-$service"
    
    # Check if image exists in ECR
    if aws ecr describe-images --repository-name "$PROJECT_NAME-$service" --image-ids imageTag=latest --region $AWS_REGION > /dev/null 2>&1; then
        print_status "✅ $service: $ECR_REPO:latest"
    else
        print_error "❌ $service: Failed to push"
    fi
done

echo ""
print_header "Deployment completed!"

# Show next steps
echo ""
print_status "Next steps:"
echo "1. Deploy infrastructure: cd terraform && terraform apply"
echo "2. Update ECS services: ./deployment/deploy-services.sh"
echo "3. Check service status: ./deployment/health-check.sh"
echo ""

# Show image information
print_status "To view images in ECR:"
echo "aws ecr describe-repositories --region $AWS_REGION"
echo "aws ecr list-images --repository-name $PROJECT_NAME-api-gateway --region $AWS_REGION"

print_status "Push to ECR completed successfully! 🚀" 