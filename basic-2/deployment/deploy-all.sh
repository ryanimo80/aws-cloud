#!/bin/bash

# Complete Deployment Script
# This script deploys the entire Django microservices infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_phase() {
    echo -e "${PURPLE}[PHASE]${NC} $1"
}

# Configuration
PROJECT_NAME="django-microservices"
CLUSTER_NAME="$PROJECT_NAME-cluster"
AWS_REGION=${AWS_REGION:-"us-east-1"}

# Check required environment variables
check_environment() {
    print_header "Checking Environment Variables..."
    
    local missing_vars=()
    
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        missing_vars+=("AWS_ACCOUNT_ID")
    fi
    
    if [ -z "$AWS_REGION" ]; then
        missing_vars+=("AWS_REGION")
    fi
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        print_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo ""
        echo "Example setup:"
        echo "  export AWS_ACCOUNT_ID=123456789012"
        echo "  export AWS_REGION=us-east-1"
        exit 1
    fi
    
    print_success "All required environment variables are set"
}

# Check dependencies
check_dependencies() {
    print_header "Checking Dependencies..."
    
    local missing_deps=()
    
    if ! command -v aws &> /dev/null; then
        missing_deps+=("aws-cli")
    fi
    
    if ! command -v terraform &> /dev/null; then
        missing_deps+=("terraform")
    fi
    
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    
    print_success "All dependencies are available"
}

# Show deployment plan
show_deployment_plan() {
    print_header "Deployment Plan"
    echo ""
    echo "Project: $PROJECT_NAME"
    echo "AWS Account: $AWS_ACCOUNT_ID"
    echo "AWS Region: $AWS_REGION"
    echo "ECS Cluster: $CLUSTER_NAME"
    echo ""
    echo "Deployment phases:"
    echo "1. 🏗️  Infrastructure Deployment (Terraform)"
    echo "2. 🐳 Container Build & Push (Docker + ECR)"
    echo "3. 🚀 Service Deployment (ECS)"
    echo "4. 🔍 Health Checks"
    echo "5. 📊 Status Report"
    echo ""
    
    # Ask for confirmation
    read -p "Do you want to proceed with deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled by user"
        exit 0
    fi
}

# Deploy infrastructure
deploy_infrastructure() {
    print_phase "PHASE 1: Infrastructure Deployment"
    
    cd terraform
    
    # Initialize Terraform
    if [ ! -d ".terraform" ]; then
        print_status "Initializing Terraform..."
        terraform init
    else
        print_status "Terraform already initialized"
    fi
    
    # Check terraform.tfvars
    if [ ! -f "terraform.tfvars" ]; then
        print_warning "terraform.tfvars not found. Using default values."
        print_status "You can copy terraform.tfvars.example to terraform.tfvars and customize it."
    fi
    
    # Plan deployment
    print_status "Planning infrastructure deployment..."
    terraform plan -out=tfplan
    
    # Apply deployment
    print_status "Deploying infrastructure..."
    terraform apply tfplan
    
    print_success "Infrastructure deployed successfully"
    cd ..
}

# Build and push containers
build_and_push_containers() {
    print_phase "PHASE 2: Container Build & Push"
    
    # Make sure the script is executable
    chmod +x deployment/push-to-ecr.sh
    
    # Run ECR push script
    print_status "Building and pushing containers to ECR..."
    ./deployment/push-to-ecr.sh
    
    print_success "Containers built and pushed successfully"
}

# Deploy services
deploy_services() {
    print_phase "PHASE 3: Service Deployment"
    
    # Make sure the script is executable
    chmod +x deployment/deploy-services.sh
    
    # Deploy services
    print_status "Deploying ECS services..."
    ./deployment/deploy-services.sh
    
    print_success "Services deployed successfully"
}

# Run health checks
run_health_checks() {
    print_phase "PHASE 4: Health Checks"
    
    # Make sure the script is executable
    chmod +x deployment/health-check.sh
    
    # Wait a bit for services to stabilize
    print_status "Waiting for services to stabilize..."
    sleep 30
    
    # Run health checks
    print_status "Running health checks..."
    ./deployment/health-check.sh
    
    print_success "Health checks completed"
}

# Generate status report
generate_status_report() {
    print_phase "PHASE 5: Status Report"
    
    # Get deployment information
    cd terraform
    local deployment_info=$(terraform output -json deployment_info)
    local load_balancer_dns=$(echo "$deployment_info" | jq -r '.load_balancer_dns')
    cd ..
    
    # Show deployment summary
    echo ""
    print_header "🎉 Deployment Summary"
    echo ""
    print_status "✅ Infrastructure: Deployed"
    print_status "✅ Containers: Built and pushed to ECR"
    print_status "✅ Services: Deployed to ECS"
    print_status "✅ Health Checks: Completed"
    echo ""
    
    # Show URLs
    print_header "📡 Service URLs"
    echo ""
    echo "  🌐 Load Balancer:    http://$load_balancer_dns"
    echo "  🚪 API Gateway:      http://$load_balancer_dns/"
    echo "  👥 User Service:     http://$load_balancer_dns/users/"
    echo "  🛍️  Product Service:  http://$load_balancer_dns/products/"
    echo "  📦 Order Service:    http://$load_balancer_dns/orders/"
    echo "  🔔 Notification:     http://$load_balancer_dns/notifications/"
    echo ""
    
    # Show management commands
    print_header "🔧 Management Commands"
    echo ""
    echo "  Health Check:        ./deployment/health-check.sh"
    echo "  Update Services:     ./deployment/deploy-services.sh"
    echo "  Push New Images:     ./deployment/push-to-ecr.sh"
    echo "  View Logs:           aws logs tail /ecs/$PROJECT_NAME/api-gateway --follow"
    echo ""
    
    # Show cost information
    print_header "💰 Cost Information"
    echo ""
    local total_tasks=$(aws ecs list-tasks --cluster $CLUSTER_NAME --region $AWS_REGION --query 'length(taskArns)' --output text 2>/dev/null || echo '0')
    local hourly_cost=$(echo "scale=2; $total_tasks * 0.22" | bc)
    local daily_cost=$(echo "scale=2; $hourly_cost * 24" | bc)
    
    echo "  Running Tasks:       $total_tasks"
    echo "  Hourly Cost:         \$$hourly_cost USD"
    echo "  Daily Cost:          \$$daily_cost USD"
    echo ""
    
    # Show next steps
    print_header "🎯 Next Steps"
    echo ""
    echo "1. Test the APIs using the URLs above"
    echo "2. Monitor services: ./deployment/health-check.sh"
    echo "3. Set up monitoring dashboards (CloudWatch)"
    echo "4. Configure custom domains (Route 53)"
    echo "5. Set up SSL certificates (ACM)"
    echo ""
    
    print_success "Deployment completed successfully! 🚀"
}

# Main deployment function
main() {
    print_header "🚀 Django Microservices Deployment"
    echo "Starting complete deployment process..."
    echo ""
    
    # Pre-deployment checks
    check_environment
    check_dependencies
    show_deployment_plan
    
    # Start deployment
    local start_time=$(date +%s)
    
    # Phase 1: Infrastructure
    deploy_infrastructure
    
    # Phase 2: Containers
    build_and_push_containers
    
    # Phase 3: Services
    deploy_services
    
    # Phase 4: Health Checks
    run_health_checks
    
    # Phase 5: Status Report
    generate_status_report
    
    # Calculate deployment time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    
    echo ""
    print_success "🎉 Total deployment time: ${minutes}m ${seconds}s"
    
    # Save deployment info
    cat > deployment-info.txt << EOF
Django Microservices Deployment
================================

Deployment Date: $(date)
Project: $PROJECT_NAME
AWS Account: $AWS_ACCOUNT_ID
AWS Region: $AWS_REGION
ECS Cluster: $CLUSTER_NAME

Load Balancer URL: http://$(cd terraform && terraform output -raw load_balancer_dns)

Service URLs:
- API Gateway: http://$(cd terraform && terraform output -raw load_balancer_dns)/
- User Service: http://$(cd terraform && terraform output -raw load_balancer_dns)/users/
- Product Service: http://$(cd terraform && terraform output -raw load_balancer_dns)/products/
- Order Service: http://$(cd terraform && terraform output -raw load_balancer_dns)/orders/
- Notification Service: http://$(cd terraform && terraform output -raw load_balancer_dns)/notifications/

Management Commands:
- Health Check: ./deployment/health-check.sh
- Update Services: ./deployment/deploy-services.sh
- Push New Images: ./deployment/push-to-ecr.sh

Deployment Duration: ${minutes}m ${seconds}s
EOF
    
    print_status "Deployment information saved to deployment-info.txt"
}

# Handle script interruption
cleanup() {
    print_warning "Deployment interrupted. Cleaning up..."
    # Add cleanup logic here if needed
    exit 130
}

trap cleanup INT TERM

# Run main function
main "$@" 