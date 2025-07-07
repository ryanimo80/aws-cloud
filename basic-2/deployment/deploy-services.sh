#!/bin/bash

# Deploy ECS Services
# This script deploys all microservices to ECS cluster

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

# Configuration
PROJECT_NAME="django-microservices"
CLUSTER_NAME="$PROJECT_NAME-cluster"
AWS_REGION=${AWS_REGION:-"us-east-1"}

# Services to deploy
SERVICES=(
    "api-gateway"
    "user-service" 
    "product-service"
    "order-service"
    "notification-service"
)

print_header "Starting ECS Service Deployment"
echo "Cluster: $CLUSTER_NAME"
echo "Region: $AWS_REGION"
echo ""

# Check if AWS CLI is installed and configured
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed"
    exit 1
fi

# Check if terraform is available
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed"
    exit 1
fi

# Function to wait for service to be stable
wait_for_service_stable() {
    local service_name=$1
    local max_wait=600  # 10 minutes
    local wait_interval=30
    local elapsed=0
    
    print_status "Waiting for $service_name to become stable..."
    
    while [ $elapsed -lt $max_wait ]; do
        local status=$(aws ecs describe-services \
            --cluster $CLUSTER_NAME \
            --services "$PROJECT_NAME-$service_name" \
            --region $AWS_REGION \
            --query 'services[0].deployments[0].status' \
            --output text 2>/dev/null || echo "UNKNOWN")
        
        if [ "$status" = "PRIMARY" ]; then
            local running=$(aws ecs describe-services \
                --cluster $CLUSTER_NAME \
                --services "$PROJECT_NAME-$service_name" \
                --region $AWS_REGION \
                --query 'services[0].runningCount' \
                --output text 2>/dev/null || echo "0")
            
            local desired=$(aws ecs describe-services \
                --cluster $CLUSTER_NAME \
                --services "$PROJECT_NAME-$service_name" \
                --region $AWS_REGION \
                --query 'services[0].desiredCount' \
                --output text 2>/dev/null || echo "1")
            
            if [ "$running" = "$desired" ] && [ "$running" != "0" ]; then
                print_status "$service_name is stable (Running: $running/$desired)"
                return 0
            fi
        fi
        
        echo -n "."
        sleep $wait_interval
        elapsed=$((elapsed + wait_interval))
    done
    
    print_warning "$service_name did not stabilize within $max_wait seconds"
    return 1
}

# Function to get service health status
get_service_health() {
    local service_name=$1
    
    # Get target group health
    local target_group_arn=$(aws elbv2 describe-target-groups \
        --names "$PROJECT_NAME-$service_name-tg" \
        --region $AWS_REGION \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$target_group_arn" ] && [ "$target_group_arn" != "None" ]; then
        local healthy_targets=$(aws elbv2 describe-target-health \
            --target-group-arn $target_group_arn \
            --region $AWS_REGION \
            --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' \
            --output text 2>/dev/null || echo "0")
        
        echo $healthy_targets
    else
        echo "0"
    fi
}

# Check if infrastructure is deployed
print_status "Checking infrastructure status..."

# Check if ECS cluster exists
if ! aws ecs describe-clusters --clusters $CLUSTER_NAME --region $AWS_REGION > /dev/null 2>&1; then
    print_error "ECS cluster $CLUSTER_NAME not found. Please deploy infrastructure first:"
    echo "cd terraform && terraform apply"
    exit 1
fi

print_status "ECS cluster found: $CLUSTER_NAME"

# Deploy using Terraform
print_header "Deploying ECS services with Terraform..."

cd terraform

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
    print_status "Initializing Terraform..."
    terraform init
fi

# Plan the deployment
print_status "Planning Terraform deployment..."
terraform plan -out=tfplan

# Apply the deployment
print_status "Applying Terraform deployment..."
terraform apply tfplan

cd ..

# Wait for all services to be deployed and stable
print_header "Waiting for services to become stable..."

for service in "${SERVICES[@]}"; do
    print_status "Checking $service..."
    
    # Check if service exists
    if aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services "$PROJECT_NAME-$service" \
        --region $AWS_REGION > /dev/null 2>&1; then
        
        # Wait for service to stabilize
        wait_for_service_stable $service
        
        # Check health
        healthy_count=$(get_service_health $service)
        if [ "$healthy_count" -gt 0 ]; then
            print_status "✅ $service: Healthy ($healthy_count targets)"
        else
            print_warning "⚠️  $service: No healthy targets"
        fi
    else
        print_error "❌ $service: Service not found"
    fi
done

# Get load balancer URL
print_header "Getting application URLs..."

ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names "$PROJECT_NAME-alb" \
    --region $AWS_REGION \
    --query 'LoadBalancers[0].DNSName' \
    --output text 2>/dev/null || echo "")

if [ -n "$ALB_DNS" ] && [ "$ALB_DNS" != "None" ]; then
    print_status "Application Load Balancer: http://$ALB_DNS"
    echo ""
    print_status "Service endpoints:"
    echo "  API Gateway:     http://$ALB_DNS/"
    echo "  User Service:    http://$ALB_DNS/users/"
    echo "  Product Service: http://$ALB_DNS/products/"
    echo "  Order Service:   http://$ALB_DNS/orders/"
    echo "  Notification:    http://$ALB_DNS/notifications/"
else
    print_warning "Load balancer DNS not found"
fi

# Show service status summary
print_header "Service Deployment Summary"
echo ""

for service in "${SERVICES[@]}"; do
    # Get service status
    local running=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services "$PROJECT_NAME-$service" \
        --region $AWS_REGION \
        --query 'services[0].runningCount' \
        --output text 2>/dev/null || echo "0")
    
    local desired=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services "$PROJECT_NAME-$service" \
        --region $AWS_REGION \
        --query 'services[0].desiredCount' \
        --output text 2>/dev/null || echo "1")
    
    local healthy_count=$(get_service_health $service)
    
    if [ "$running" = "$desired" ] && [ "$running" != "0" ] && [ "$healthy_count" -gt 0 ]; then
        print_status "✅ $service: $running/$desired running, $healthy_count healthy"
    elif [ "$running" = "$desired" ] && [ "$running" != "0" ]; then
        print_warning "⚠️  $service: $running/$desired running, $healthy_count healthy"
    else
        print_error "❌ $service: $running/$desired running, $healthy_count healthy"
    fi
done

echo ""
print_header "Deployment completed!"

# Show monitoring commands
echo ""
print_status "Monitoring commands:"
echo "  Check services:      ./deployment/health-check.sh"
echo "  View service logs:   aws ecs describe-services --cluster $CLUSTER_NAME --services $PROJECT_NAME-api-gateway"
echo "  View task logs:      aws logs tail /ecs/$PROJECT_NAME/api-gateway --follow"
echo "  Scale service:       aws ecs update-service --cluster $CLUSTER_NAME --service $PROJECT_NAME-api-gateway --desired-count 2"

# Show cost information
echo ""
print_status "Cost monitoring:"
echo "  Current tasks running: $(aws ecs list-tasks --cluster $CLUSTER_NAME --region $AWS_REGION --query 'length(taskArns)' --output text 2>/dev/null || echo '0')"
echo "  Estimated hourly cost: \$1.10 (5 services × 256 vCPU × 512MB)"

print_status "ECS deployment completed successfully! 🚀" 