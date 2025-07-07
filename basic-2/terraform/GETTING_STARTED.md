# 🚀 Getting Started với Terraform Structure Mới

## 📋 **Chuẩn bị trước khi bắt đầu**

### **1. Kiểm tra Prerequisites**
```bash
# Check Terraform version
terraform version # >= 1.5 required

# Check AWS CLI
aws --version
aws configure list # Make sure AWS credentials are configured

# Check kubectl (optional for ECS)
kubectl version --client
```

### **2. Clone và Setup**
```bash
cd basic-2/terraform
ls -la  # You should see: core/, advanced/, configuration/
```

## 🎯 **Deployment Options**

### **Option 1: Core Infrastructure Only (Recommended để bắt đầu)**
```bash
# Step 1: Review configuration
cat configuration/terraform.tfvars.core

# Step 2: Deploy core infrastructure
terraform init
terraform plan -var-file="configuration/terraform.tfvars.core"
terraform apply -var-file="configuration/terraform.tfvars.core"

# Step 3: Verify deployment
terraform output
```

### **Option 2: Full Infrastructure**
```bash
# Step 1: Review full configuration
cat configuration/terraform.tfvars.example

# Step 2: Deploy everything
terraform init
terraform plan -var-file="configuration/terraform.tfvars.example"
terraform apply -var-file="configuration/terraform.tfvars.example"
```

### **Option 3: Automated Scripts**
```bash
# Make scripts executable
chmod +x deploy-core.sh deploy-full.sh

# Deploy core only
./deploy-core.sh

# OR deploy full infrastructure
./deploy-full.sh
```

## 📝 **Step-by-Step Deployment Guide**

### **Phase 1: Core Infrastructure (Phase 2)**
```bash
# 1. Initialize Terraform
terraform init

# 2. Validate configuration
terraform validate

# 3. Plan deployment
terraform plan -var-file="configuration/terraform.tfvars.core"

# 4. Apply core infrastructure
terraform apply -var-file="configuration/terraform.tfvars.core"

# 5. Check outputs
terraform output
```

### **Phase 2: Enable Advanced Features (Phase 6-7)**
```bash
# 1. Update tfvars file
nano configuration/terraform.tfvars.example
# Set: enable_advanced_features = true

# 2. Plan advanced features
terraform plan -var-file="configuration/terraform.tfvars.example"

# 3. Apply advanced infrastructure
terraform apply -var-file="configuration/terraform.tfvars.example"
```

## 🔧 **Configuration Customization**

### **1. Core Infrastructure Variables**
```hcl
# configuration/terraform.tfvars.core

# Project settings
project_name = "your-project"
environment  = "dev"
aws_region   = "us-east-1"

# Cost optimization
database_instance_class = "db.t3.micro"  # Change for production
redis_node_type = "cache.t3.micro"       # Change for production
single_nat_gateway = true                 # false for production
```

### **2. Advanced Features Configuration**
```hcl
# configuration/terraform.tfvars.example

# Feature flags
enable_advanced_features = true
enable_monitoring = true
enable_security = true
enable_backup = true
enable_autoscaling = true

# Monitoring
alert_email_addresses = ["admin@company.com"]
security_email_addresses = ["security@company.com"]

# Auto-scaling
autoscaling_min_capacity = 1
autoscaling_max_capacity = 10
autoscaling_cpu_target = 70
```

## 🛠️ **Common Commands**

### **Development Workflow**
```bash
# Check current state
terraform show

# Plan changes
terraform plan

# Apply specific target
terraform apply -target=module.core

# Check outputs
terraform output

# Show state
terraform state list
```

### **Troubleshooting**
```bash
# Validate configuration
terraform validate

# Format code
terraform fmt -recursive

# Check for unused variables
terraform plan -detailed-exitcode

# Refresh state
terraform refresh
```

## 🎯 **Development Workflow**

### **1. Start with Core**
```bash
# Deploy basic infrastructure first
terraform apply -var-file="configuration/terraform.tfvars.core" -target=module.core
```

### **2. Add Services Gradually**
```bash
# Deploy ECS services
terraform apply -target=module.advanced[0].aws_ecs_service

# Add monitoring
terraform apply -target=module.advanced[0].aws_cloudwatch_dashboard
```

### **3. Scale as Needed**
```bash
# Enable auto-scaling
terraform apply -var="enable_autoscaling=true"

# Add performance optimization
terraform apply -var="enable_performance=true"
```

## 💡 **Best Practices**

### **1. Resource Naming**
- All resources follow pattern: `{project_name}-{resource_type}-{environment}`
- Example: `django-microservices-vpc-dev`

### **2. Cost Management**
```bash
# Start with minimal resources
database_instance_class = "db.t3.micro"
redis_node_type = "cache.t3.micro"
single_nat_gateway = true

# Scale up for production
database_instance_class = "db.t3.medium"
redis_node_type = "cache.t3.medium"
single_nat_gateway = false
```

### **3. Security**
```bash
# Enable security features
enable_security = true
database_deletion_protection = true
enable_deletion_protection = true
```

### **4. Monitoring**
```bash
# Enable comprehensive monitoring
enable_monitoring = true
log_retention_days = 30
alert_email_addresses = ["team@company.com"]
```

## 🚨 **Common Issues & Solutions**

### **Issue 1: Permission Denied**
```bash
# Solution: Check AWS credentials
aws sts get-caller-identity
aws configure list
```

### **Issue 2: Resource Already Exists**
```bash
# Solution: Import existing resources
terraform import aws_vpc.main vpc-xxxxxx
```

### **Issue 3: Dependencies Error**
```bash
# Solution: Deploy in order
terraform apply -target=module.core
terraform apply -target=module.advanced
```

### **Issue 4: Cost Concerns**
```bash
# Solution: Use cost-optimized settings
single_nat_gateway = true
database_instance_class = "db.t3.micro"
enable_advanced_features = false
```

## 📊 **Cost Estimation**

### **Development Environment**
- Core Infrastructure: ~$75/month
- Advanced Features: ~$115/month
- Total: ~$190/month

### **Production Environment**
- Core Infrastructure: ~$150/month
- Advanced Features: ~$200/month
- Total: ~$350/month

## 🎉 **Next Steps**

### **1. After Core Deployment**
- Test database connectivity
- Verify ECS cluster
- Check ALB functionality

### **2. After Advanced Deployment**
- Configure monitoring alerts
- Test backup procedures
- Review security settings

### **3. Production Readiness**
- Enable multi-AZ
- Configure backup retention
- Set up monitoring alerts
- Enable security features

## 📚 **Documentation References**

- `core/CORE_README.md` - Core infrastructure details
- `DIRECTORY_STRUCTURE.md` - Complete structure overview
- `REFACTORING_COMPLETE.md` - Refactoring summary
- `configuration/terraform.tfvars.core` - Core configuration
- `configuration/terraform.tfvars.example` - Full configuration

---

## 🆘 **Need Help?**

1. **Check documentation** in các thư mục con
2. **Validate configuration**: `terraform validate`
3. **Plan before apply**: `terraform plan`
4. **Start with core**: Deploy core infrastructure first
5. **Contact team**: Nếu có issues phức tạp

**Happy Terraforming!** 🚀 