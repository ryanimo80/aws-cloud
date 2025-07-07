#!/bin/bash

# Script to organize Terraform files into core, advanced, and configuration directories
# This script copies files to new structure and creates symlinks for compatibility

echo "🔧 Organizing Terraform files into structured directories..."

# Create directories if they don't exist
mkdir -p core advanced configuration

echo "📁 Created directories: core, advanced, configuration"

# Copy core infrastructure files (Phase 2)
echo "📦 Copying Core Infrastructure files..."
if [ -f "rds.tf" ]; then
    cp rds.tf core/rds.tf
    echo "   ✅ rds.tf -> core/"
fi

if [ -f "redis.tf" ]; then
    cp redis.tf core/redis.tf
    echo "   ✅ redis.tf -> core/"
fi

if [ -f "alb.tf" ]; then
    cp alb.tf core/alb.tf
    echo "   ✅ alb.tf -> core/"
fi

# Copy advanced infrastructure files (Phase 6-7)
echo "🚀 Copying Advanced Infrastructure files..."
advanced_files=(
    "monitoring.tf"
    "security.tf" 
    "backup.tf"
    "autoscaling-advanced.tf"
    "performance.tf"
    "cost-optimization.tf"
    "load-testing.tf"
    "ecs-services.tf"
    "ecs-tasks.tf"
)

for file in "${advanced_files[@]}"; do
    if [ -f "$file" ]; then
        cp "$file" "advanced/$file"
        echo "   ✅ $file -> advanced/"
    fi
done

# Copy configuration files
echo "⚙️  Copying Configuration files..."
config_files=(
    "versions.tf"
    "variables.tf"
    "outputs.tf"
    "terraform.tfvars.example"
    "terraform.tfvars.simple"
    "README.md"
)

for file in "${config_files[@]}"; do
    if [ -f "$file" ]; then
        cp "$file" "configuration/$file"
        echo "   ✅ $file -> configuration/"
    fi
done

# Create main Terraform configuration that sources modules
echo "📝 Creating main.tf with module structure..."
cat > main.tf << 'EOF'
# Main Terraform Configuration
# Structured deployment with modules

# Core Infrastructure Module (Phase 2)
module "core" {
  source = "./core"
  
  # Pass all variables to core module
  project_name = var.project_name
  environment = var.environment
  aws_region = var.aws_region
  
  vpc_cidr = var.vpc_cidr
  availability_zones = var.availability_zones
  enable_nat_gateway = var.enable_nat_gateway
  single_nat_gateway = var.single_nat_gateway
  
  database_instance_class = var.database_instance_class
  database_allocated_storage = var.database_allocated_storage
  database_max_allocated_storage = var.database_max_allocated_storage
  database_backup_retention_period = var.database_backup_retention_period
  database_multi_az = var.database_multi_az
  database_deletion_protection = var.database_deletion_protection
  
  redis_node_type = var.redis_node_type
  redis_num_cache_nodes = var.redis_num_cache_nodes
  
  ecs_task_cpu = var.ecs_task_cpu
  ecs_task_memory = var.ecs_task_memory
  ecs_service_desired_count = var.ecs_service_desired_count
  
  microservices = var.microservices
  microservice_ports = var.microservice_ports
  
  allowed_cidr_blocks = var.allowed_cidr_blocks
  enable_deletion_protection = var.enable_deletion_protection
  log_retention_days = var.log_retention_days
  
  additional_tags = var.additional_tags
}

# Advanced Infrastructure Module (Phase 6-7) - Optional
module "advanced" {
  source = "./advanced"
  count = var.enable_advanced_features ? 1 : 0
  
  # Dependencies from core module
  vpc_id = module.core.vpc_id
  private_subnet_ids = module.core.private_subnet_ids
  public_subnet_ids = module.core.public_subnet_ids
  ecs_cluster_name = module.core.ecs_cluster_name
  alb_arn = module.core.alb_arn
  
  # Pass all variables
  project_name = var.project_name
  environment = var.environment
  aws_region = var.aws_region
  
  # Advanced feature flags
  enable_monitoring = var.enable_monitoring
  enable_security = var.enable_security
  enable_backup = var.enable_backup
  enable_autoscaling = var.enable_autoscaling
  enable_performance = var.enable_performance
  enable_cost_optimization = var.enable_cost_optimization
  enable_load_testing = var.enable_load_testing
  
  additional_tags = var.additional_tags
}
EOF

echo "✅ Created main.tf with module structure"

# Create deployment scripts
echo "🚀 Creating deployment scripts..."

# Core only deployment script
cat > deploy-core.sh << 'EOF'
#!/bin/bash
echo "🚀 Deploying Core Infrastructure (Phase 2) only..."
terraform init
terraform plan -var-file="configuration/terraform.tfvars.simple" -target=module.core
terraform apply -var-file="configuration/terraform.tfvars.simple" -target=module.core
EOF

# Full deployment script  
cat > deploy-full.sh << 'EOF'
#!/bin/bash
echo "🚀 Deploying Full Infrastructure (All Phases)..."
terraform init
terraform plan -var-file="configuration/terraform.tfvars.example"
terraform apply -var-file="configuration/terraform.tfvars.example"
EOF

chmod +x deploy-core.sh deploy-full.sh

echo "✅ Created deployment scripts: deploy-core.sh, deploy-full.sh"

# Create directory overview
echo "📊 Creating directory overview..."
cat > DIRECTORY_STRUCTURE.md << 'EOF'
# Terraform Directory Structure

## 📁 **Organized Structure**

```
terraform/
├── 📂 core/                    # Phase 2: Basic Infrastructure
│   ├── vpc.tf                  # VPC, subnets, networking
│   ├── security-groups.tf      # Security groups
│   ├── ecs.tf                  # ECS cluster, IAM
│   ├── rds.tf                  # PostgreSQL database
│   ├── redis.tf                # ElastiCache Redis
│   ├── alb.tf                  # Application Load Balancer
│   └── CORE_README.md          # Core documentation
├── 📂 advanced/                # Phase 6-7: Advanced Features
│   ├── monitoring.tf           # CloudWatch monitoring
│   ├── security.tf             # WAF, GuardDuty, security
│   ├── backup.tf               # AWS Backup, DR
│   ├── autoscaling-advanced.tf # Auto-scaling
│   ├── performance.tf          # Performance optimization
│   ├── cost-optimization.tf    # Cost management
│   ├── load-testing.tf         # Load testing
│   ├── ecs-services.tf         # ECS service definitions
│   └── ecs-tasks.tf            # ECS task definitions
├── 📂 configuration/           # Configuration Files
│   ├── versions.tf             # Provider versions
│   ├── variables.tf            # All variables
│   ├── outputs.tf              # All outputs
│   ├── terraform.tfvars.simple # Core infrastructure
│   ├── terraform.tfvars.example # Full infrastructure
│   └── README.md               # Configuration docs
├── main.tf                     # Module orchestration
├── deploy-core.sh              # Core deployment script
├── deploy-full.sh              # Full deployment script
└── DIRECTORY_STRUCTURE.md      # This file
```

## 🚀 **Deployment Options**

### **1. Core Infrastructure Only (Phase 2)**
```bash
./deploy-core.sh
# OR
terraform apply -var-file="configuration/terraform.tfvars.simple" -target=module.core
```

### **2. Full Infrastructure (All Phases)**
```bash
./deploy-full.sh
# OR
terraform apply -var-file="configuration/terraform.tfvars.example"
```

### **3. Selective Deployment**
```bash
# Deploy specific modules
terraform apply -target=module.core
terraform apply -target=module.advanced
```

## 📊 **Benefits of New Structure**

✅ **Modular Design** - Each directory has specific purpose
✅ **Clean Separation** - Core vs Advanced features
✅ **Easy Deployment** - Target specific components
✅ **Better Organization** - Logical file grouping
✅ **Scalable** - Easy to add new modules
✅ **Maintainable** - Clear dependencies
EOF

echo "✅ Created DIRECTORY_STRUCTURE.md"

echo ""
echo "🎉 File organization completed!"
echo ""
echo "📁 New structure:"
echo "   ├── core/          (Phase 2 basic infrastructure)"
echo "   ├── advanced/      (Phase 6-7 advanced features)"
echo "   ├── configuration/ (Variables, outputs, providers)"
echo "   └── main.tf        (Module orchestration)"
echo ""
echo "🚀 Deployment options:"
echo "   ./deploy-core.sh   (Core infrastructure only)"
echo "   ./deploy-full.sh   (Complete infrastructure)"
echo ""
echo "📖 See DIRECTORY_STRUCTURE.md for detailed information" 