#!/bin/bash

# Core Infrastructure Deployment Script
# This script deploys only the core infrastructure (Phase 2)

set -e

echo "🚀 Deploying Core Infrastructure (Phase 2) for Django Microservices..."

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

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please install Terraform first."
    exit 1
fi

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

# Check if configuration file exists
if [ ! -f "configuration/terraform.tfvars.core" ]; then
    print_error "Configuration file 'configuration/terraform.tfvars.core' not found."
    print_warning "Please create the configuration file first."
    exit 1
fi

print_status "Configuration found: configuration/terraform.tfvars.core"

# Show configuration
print_status "Current configuration:"
cat configuration/terraform.tfvars.core

echo ""
read -p "Do you want to continue with this configuration? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled by user."
    exit 1
fi

# Initialize Terraform
print_status "Initializing Terraform..."
terraform init

# Validate configuration
print_status "Validating Terraform configuration..."
terraform validate

if [ $? -ne 0 ]; then
    print_error "Terraform validation failed. Please check your configuration."
    exit 1
fi

# Plan deployment
print_status "Planning infrastructure deployment..."
terraform plan -var-file="configuration/terraform.tfvars.core" -target=module.core -out=core.tfplan

if [ $? -ne 0 ]; then
    print_error "Terraform plan failed. Please check the output above."
    exit 1
fi

# Confirm deployment
echo ""
print_warning "This will create AWS resources that may incur charges."
print_warning "Estimated cost: ~$75-100/month for development environment"
echo ""
read -p "Do you want to apply these changes? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled by user."
    rm -f core.tfplan
    exit 1
fi

# Apply deployment
print_status "Deploying core infrastructure..."
terraform apply core.tfplan

if [ $? -eq 0 ]; then
    print_status "✅ Core infrastructure deployed successfully!"
    
    # Show important outputs
    print_status "Important outputs:"
    terraform output -json | jq -r '.core_outputs.value | to_entries[] | "\(.key): \(.value)"' 2>/dev/null || terraform output
    
    echo ""
    print_status "🎉 Deployment completed successfully!"
    print_status "You can now:"
    print_status "1. Deploy ECS services and tasks"
    print_status "2. Push Docker images to ECR"
    print_status "3. Enable advanced features with: ./deploy-full.sh"
    
    # Clean up plan file
    rm -f core.tfplan
else
    print_error "Deployment failed. Please check the output above."
    rm -f core.tfplan
    exit 1
fi

echo ""
print_status "Next steps:"
print_status "- Check ALB DNS name: terraform output -raw alb_dns_name"
print_status "- Check ECR repositories: terraform output -json ecr_repository_urls"
print_status "- Deploy services: terraform apply -target=module.advanced" 