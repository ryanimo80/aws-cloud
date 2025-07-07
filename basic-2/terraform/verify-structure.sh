#!/bin/bash

# Verify Terraform Structure Script
# This script verifies that the folder structure has been organized correctly

echo "🔍 Verifying Terraform Folder Structure..."

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if we're in the right directory
if [ ! -f "main.tf" ]; then
    print_error "Not in terraform directory. Please run this script from the terraform/ directory."
    exit 1
fi

print_info "Current directory: $(pwd)"
echo ""

# Check directory structure
print_info "Checking directory structure..."

# Check core directory
if [ -d "core" ]; then
    print_success "core/ directory exists"
    
    # Check core files
    core_files=("vpc.tf" "security-groups.tf" "ecs.tf" "rds.tf" "redis.tf" "alb.tf" "ecr.tf" "variables.tf" "outputs.tf")
    for file in "${core_files[@]}"; do
        if [ -f "core/$file" ]; then
            print_success "core/$file exists"
        else
            print_error "core/$file missing"
        fi
    done
else
    print_error "core/ directory missing"
fi

echo ""

# Check advanced directory
if [ -d "advanced" ]; then
    print_success "advanced/ directory exists"
    
    # Check advanced files
    advanced_files=("monitoring.tf" "security.tf" "backup.tf" "autoscaling-advanced.tf" "performance.tf" "cost-optimization.tf" "load-testing.tf" "ecs-services.tf" "ecs-tasks.tf" "variables.tf" "outputs.tf")
    for file in "${advanced_files[@]}"; do
        if [ -f "advanced/$file" ]; then
            print_success "advanced/$file exists"
        else
            print_error "advanced/$file missing"
        fi
    done
else
    print_error "advanced/ directory missing"
fi

echo ""

# Check configuration directory
if [ -d "configuration" ]; then
    print_success "configuration/ directory exists"
    
    # Check configuration files
    config_files=("versions.tf" "variables.tf" "outputs.tf" "terraform.tfvars.core" "terraform.tfvars.example")
    for file in "${config_files[@]}"; do
        if [ -f "configuration/$file" ]; then
            print_success "configuration/$file exists"
        else
            print_error "configuration/$file missing"
        fi
    done
else
    print_error "configuration/ directory missing"
fi

echo ""

# Check main files
print_info "Checking main files..."
main_files=("main.tf" "deploy-core.sh" "deploy-full.sh" "README.md" "GETTING_STARTED.md")
for file in "${main_files[@]}"; do
    if [ -f "$file" ]; then
        print_success "$file exists"
    else
        print_error "$file missing"
    fi
done

# Check if scripts are executable
echo ""
print_info "Checking script permissions..."
scripts=("deploy-core.sh" "deploy-full.sh" "organize-files.sh")
for script in "${scripts[@]}"; do
    if [ -f "$script" ]; then
        if [ -x "$script" ]; then
            print_success "$script is executable"
        else
            print_warning "$script is not executable (run: chmod +x $script)"
        fi
    fi
done

echo ""

# Validate Terraform configuration
print_info "Validating Terraform configuration..."
if command -v terraform &> /dev/null; then
    if terraform validate &> /dev/null; then
        print_success "Terraform configuration is valid"
    else
        print_warning "Terraform validation failed - check configuration"
        terraform validate
    fi
else
    print_warning "Terraform not installed - skipping validation"
fi

echo ""

# Count files in each directory
print_info "File count summary:"
echo "  📂 core/: $(ls core/ | wc -l) files"
echo "  📂 advanced/: $(ls advanced/ | wc -l) files"
echo "  📂 configuration/: $(ls configuration/ | wc -l) files"
echo "  📂 root: $(ls -1 *.tf *.sh *.md 2>/dev/null | wc -l) main files"

echo ""

# Structure visualization
print_info "Current structure visualization:"
cat << 'EOF'
terraform/
├── 📂 core/                    # Phase 2: Core Infrastructure
│   ├── vpc.tf                  # VPC, subnets, networking
│   ├── security-groups.tf      # Security groups
│   ├── ecs.tf                  # ECS cluster, IAM roles
│   ├── rds.tf                  # PostgreSQL database
│   ├── redis.tf                # ElastiCache Redis
│   ├── alb.tf                  # Application Load Balancer
│   ├── ecr.tf                  # ECR repositories
│   ├── variables.tf            # Core variables
│   └── outputs.tf              # Core outputs
├── 📂 advanced/                # Phase 6-7: Advanced Features
│   ├── monitoring.tf           # CloudWatch monitoring
│   ├── security.tf             # WAF, GuardDuty, security
│   ├── backup.tf               # AWS Backup, DR
│   ├── autoscaling-advanced.tf # Auto-scaling policies
│   ├── performance.tf          # Performance optimization
│   ├── cost-optimization.tf    # Cost management
│   ├── load-testing.tf         # Load testing
│   ├── ecs-services.tf         # ECS service definitions
│   ├── ecs-tasks.tf            # ECS task definitions
│   ├── variables.tf            # Advanced variables
│   └── outputs.tf              # Advanced outputs
├── 📂 configuration/           # Configuration Management
│   ├── versions.tf             # Provider versions
│   ├── variables.tf            # All variables
│   ├── outputs.tf              # All outputs
│   ├── terraform.tfvars.core   # Core infrastructure config
│   └── terraform.tfvars.example # Full infrastructure config
├── main.tf                     # Module orchestration
├── deploy-core.sh              # Core deployment script
├── deploy-full.sh              # Full deployment script
├── README.md                   # Project documentation
└── GETTING_STARTED.md          # Getting started guide
EOF

echo ""

# Final summary
print_info "📊 Structure Verification Summary:"

# Count successful checks
total_checks=0
passed_checks=0

# Simple check logic (this is a basic implementation)
if [ -d "core" ] && [ -d "advanced" ] && [ -d "configuration" ]; then
    print_success "All required directories exist"
    ((passed_checks++))
fi
((total_checks++))

if [ -f "main.tf" ] && [ -f "deploy-core.sh" ] && [ -f "deploy-full.sh" ]; then
    print_success "All main files exist"
    ((passed_checks++))
fi
((total_checks++))

if [ -f "core/variables.tf" ] && [ -f "advanced/variables.tf" ] && [ -f "configuration/variables.tf" ]; then
    print_success "All variable files exist"
    ((passed_checks++))
fi
((total_checks++))

echo ""
print_info "Verification Result: $passed_checks/$total_checks checks passed"

if [ $passed_checks -eq $total_checks ]; then
    print_success "🎉 Folder structure is correctly organized!"
    print_success "You can now deploy using:"
    echo "  • Core only: ./deploy-core.sh"
    echo "  • Full infrastructure: ./deploy-full.sh"
else
    print_warning "Some issues found. Please check the output above."
fi

echo ""
print_info "Next steps:"
echo "  1. Review configuration files in configuration/"
echo "  2. Test deployment with: terraform plan"
echo "  3. Deploy core infrastructure: ./deploy-core.sh"
echo "  4. Deploy advanced features: ./deploy-full.sh" 