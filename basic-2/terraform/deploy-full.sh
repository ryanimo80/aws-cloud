#!/bin/bash

# Full Infrastructure Deployment Script
# This script deploys the complete infrastructure (All Phases)

set -e

echo "🚀 Deploying Full Infrastructure (All Phases) for Django Microservices..."

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

print_feature() {
    echo -e "${BLUE}[FEATURE]${NC} $1"
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
if [ ! -f "configuration/terraform.tfvars.example" ]; then
    print_error "Configuration file 'configuration/terraform.tfvars.example' not found."
    print_warning "Please create the configuration file first."
    exit 1
fi

print_status "Configuration found: configuration/terraform.tfvars.example"

# Show configuration
print_status "Current configuration:"
cat configuration/terraform.tfvars.example

echo ""
print_warning "This will deploy the complete infrastructure including:"
print_feature "✅ Core Infrastructure (VPC, ECS, RDS, Redis, ALB)"
print_feature "✅ Advanced Monitoring (CloudWatch, Dashboards, Alarms)"
print_feature "✅ Security Features (WAF, GuardDuty, CloudTrail)"
print_feature "✅ Backup & Disaster Recovery (AWS Backup, Cross-region)"
print_feature "✅ Auto-scaling (ECS, RDS, Redis)"
print_feature "✅ Performance Optimization (CloudFront, Read Replicas)"
print_feature "✅ Cost Optimization (Spot instances, Reserved capacity)"
print_feature "✅ Load Testing Infrastructure"

echo ""
print_warning "Estimated cost: ~$190-250/month for development environment"
print_warning "Estimated cost: ~$350-450/month for production environment"

echo ""
read -p "Do you want to continue with full infrastructure deployment? (y/n): " -n 1 -r
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
print_status "Planning complete infrastructure deployment..."
terraform plan -var-file="configuration/terraform.tfvars.example" -out=full.tfplan

if [ $? -ne 0 ]; then
    print_error "Terraform plan failed. Please check the output above."
    exit 1
fi

# Final confirmation
echo ""
print_warning "⚠️  FINAL CONFIRMATION ⚠️"
print_warning "This will create extensive AWS resources with significant costs."
print_warning "Make sure you understand the pricing implications."
echo ""
read -p "Are you absolutely sure you want to deploy the full infrastructure? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled by user."
    rm -f full.tfplan
    exit 1
fi

# Apply deployment
print_status "Deploying complete infrastructure..."
print_status "This may take 15-20 minutes..."

terraform apply full.tfplan

if [ $? -eq 0 ]; then
    print_status "✅ Full infrastructure deployed successfully!"
    
    # Show important outputs
    print_status "📊 Deployment Summary:"
    terraform output -json | jq -r '.deployment_summary.value | to_entries[] | "\(.key): \(.value)"' 2>/dev/null || terraform output
    
    echo ""
    print_status "🎉 Complete deployment finished!"
    print_status "🔗 Important URLs:"
    
    # Show core outputs
    print_status "Core Infrastructure:"
    terraform output -json | jq -r '.core_outputs.value | to_entries[] | "  \(.key): \(.value)"' 2>/dev/null || echo "  Check: terraform output core_outputs"
    
    # Show advanced outputs
    print_status "Advanced Features:"
    terraform output -json | jq -r '.advanced_outputs.value | to_entries[] | "  \(.key): \(.value)"' 2>/dev/null || echo "  Check: terraform output advanced_outputs"
    
    echo ""
    print_status "🛠️  Next Steps:"
    print_status "1. 🐳 Push Docker images to ECR repositories"
    print_status "2. 🚀 Deploy ECS services and tasks"
    print_status "3. 📊 Configure monitoring alerts"
    print_status "4. 🔒 Review security settings"
    print_status "5. 💾 Test backup procedures"
    print_status "6. 🧪 Run load tests"
    
    echo ""
    print_status "📚 Documentation:"
    print_status "- ALB DNS: terraform output -raw alb_dns_name"
    print_status "- ECR URLs: terraform output -json ecr_repository_urls"
    print_status "- Monitoring: terraform output -json monitoring_dashboard_url"
    print_status "- Security: terraform output -json waf_web_acl_arn"
    
    # Clean up plan file
    rm -f full.tfplan
else
    print_error "Deployment failed. Please check the output above."
    rm -f full.tfplan
    exit 1
fi

echo ""
print_status "🎯 Production Readiness Checklist:"
print_status "□ Update database instance class for production"
print_status "□ Enable Multi-AZ for RDS"
print_status "□ Configure SSL/TLS certificates"
print_status "□ Set up monitoring alerts"
print_status "□ Configure backup notifications"
print_status "□ Review security group rules"
print_status "□ Test disaster recovery procedures"

echo ""
print_status "💰 Cost Monitoring:"
print_status "- Check AWS Cost Explorer for actual costs"
print_status "- Set up billing alerts"
print_status "- Review resource utilization"
print_status "- Consider Reserved Instances for production" 