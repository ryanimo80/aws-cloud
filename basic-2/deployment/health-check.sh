#!/bin/bash

# Health Check Script for ECS Services
# This script checks the health status of all microservices

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
    echo -e "${BLUE}[HEALTH]${NC} $1"
}

# Configuration
PROJECT_NAME="django-microservices"
CLUSTER_NAME="$PROJECT_NAME-cluster"
AWS_REGION=${AWS_REGION:-"us-east-1"}

# Services to check
SERVICES=(
    "api-gateway"
    "user-service"
    "product-service"
    "order-service"
    "notification-service"
)

print_header "Health Check for $PROJECT_NAME"
echo "Cluster: $CLUSTER_NAME"
echo "Region: $AWS_REGION"
echo "Time: $(date)"
echo ""

# Check if AWS CLI is available
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed"
    exit 1
fi

# Function to check ECS service health
check_ecs_service() {
    local service_name=$1
    
    # Get service information
    local service_info=$(aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services "$PROJECT_NAME-$service_name" \
        --region $AWS_REGION 2>/dev/null)
    
    if [ $? -ne 0 ] || [ -z "$service_info" ]; then
        echo "NOT_FOUND|0|0|UNKNOWN"
        return
    fi
    
    local running=$(echo "$service_info" | jq -r '.services[0].runningCount // 0')
    local desired=$(echo "$service_info" | jq -r '.services[0].desiredCount // 0')
    local status=$(echo "$service_info" | jq -r '.services[0].status // "UNKNOWN"')
    
    echo "$status|$running|$desired|ECS"
}

# Function to check target group health
check_target_group_health() {
    local service_name=$1
    
    # Get target group ARN
    local target_group_arn=$(aws elbv2 describe-target-groups \
        --names "$PROJECT_NAME-$service_name-tg" \
        --region $AWS_REGION \
        --query 'TargetGroups[0].TargetGroupArn' \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$target_group_arn" ] || [ "$target_group_arn" = "None" ]; then
        echo "0|0|NO_TG"
        return
    fi
    
    # Get target health
    local health_info=$(aws elbv2 describe-target-health \
        --target-group-arn $target_group_arn \
        --region $AWS_REGION 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo "0|0|ERROR"
        return
    fi
    
    local total_targets=$(echo "$health_info" | jq -r '.TargetHealthDescriptions | length')
    local healthy_targets=$(echo "$health_info" | jq -r '[.TargetHealthDescriptions[] | select(.TargetHealth.State == "healthy")] | length')
    
    echo "$healthy_targets|$total_targets|TG"
}

# Function to check HTTP endpoint
check_http_endpoint() {
    local url=$1
    local timeout=5
    
    local response=$(curl -s --max-time $timeout --write-out "HTTPSTATUS:%{http_code}" "$url" 2>/dev/null || echo "HTTPSTATUS:000")
    local http_code=$(echo "$response" | grep -o "HTTPSTATUS:[0-9]*" | cut -d: -f2)
    
    if [ "$http_code" = "200" ]; then
        echo "HEALTHY"
    elif [ "$http_code" = "000" ]; then
        echo "TIMEOUT"
    else
        echo "HTTP_$http_code"
    fi
}

# Get load balancer DNS
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --names "$PROJECT_NAME-alb" \
    --region $AWS_REGION \
    --query 'LoadBalancers[0].DNSName' \
    --output text 2>/dev/null || echo "")

# Check infrastructure components
print_header "Infrastructure Health"

# Check ECS Cluster
if aws ecs describe-clusters --clusters $CLUSTER_NAME --region $AWS_REGION > /dev/null 2>&1; then
    local cluster_status=$(aws ecs describe-clusters \
        --clusters $CLUSTER_NAME \
        --region $AWS_REGION \
        --query 'clusters[0].status' \
        --output text)
    
    if [ "$cluster_status" = "ACTIVE" ]; then
        print_status "✅ ECS Cluster: $cluster_status"
    else
        print_warning "⚠️  ECS Cluster: $cluster_status"
    fi
else
    print_error "❌ ECS Cluster: NOT_FOUND"
fi

# Check Load Balancer
if [ -n "$ALB_DNS" ] && [ "$ALB_DNS" != "None" ]; then
    local alb_state=$(aws elbv2 describe-load-balancers \
        --names "$PROJECT_NAME-alb" \
        --region $AWS_REGION \
        --query 'LoadBalancers[0].State.Code' \
        --output text 2>/dev/null || echo "unknown")
    
    if [ "$alb_state" = "active" ]; then
        print_status "✅ Load Balancer: $alb_state"
        print_status "   URL: http://$ALB_DNS"
    else
        print_warning "⚠️  Load Balancer: $alb_state"
    fi
else
    print_error "❌ Load Balancer: NOT_FOUND"
fi

# Check Database
local db_status=$(aws rds describe-db-instances \
    --db-instance-identifier "$PROJECT_NAME-postgres" \
    --region $AWS_REGION \
    --query 'DBInstances[0].DBInstanceStatus' \
    --output text 2>/dev/null || echo "not-found")

if [ "$db_status" = "available" ]; then
    print_status "✅ Database: $db_status"
else
    print_warning "⚠️  Database: $db_status"
fi

# Check Redis
local redis_status=$(aws elasticache describe-cache-clusters \
    --cache-cluster-id "$PROJECT_NAME-redis" \
    --region $AWS_REGION \
    --query 'CacheClusters[0].CacheClusterStatus' \
    --output text 2>/dev/null || echo "not-found")

if [ "$redis_status" = "available" ]; then
    print_status "✅ Redis: $redis_status"
else
    print_warning "⚠️  Redis: $redis_status"
fi

echo ""

# Check service health
print_header "Microservices Health"

# Service endpoints for HTTP checks
declare -A SERVICE_ENDPOINTS
if [ -n "$ALB_DNS" ] && [ "$ALB_DNS" != "None" ]; then
    SERVICE_ENDPOINTS["api-gateway"]="http://$ALB_DNS/health/"
    SERVICE_ENDPOINTS["user-service"]="http://$ALB_DNS/users/health/"
    SERVICE_ENDPOINTS["product-service"]="http://$ALB_DNS/products/health/"
    SERVICE_ENDPOINTS["order-service"]="http://$ALB_DNS/orders/health/"
    SERVICE_ENDPOINTS["notification-service"]="http://$ALB_DNS/notifications/health/"
fi

for service in "${SERVICES[@]}"; do
    echo -n "Checking $service... "
    
    # Check ECS service
    ecs_health=$(check_ecs_service $service)
    IFS='|' read -r ecs_status ecs_running ecs_desired ecs_type <<< "$ecs_health"
    
    # Check target group
    tg_health=$(check_target_group_health $service)
    IFS='|' read -r tg_healthy tg_total tg_type <<< "$tg_health"
    
    # Check HTTP endpoint
    http_status="N/A"
    if [ -n "${SERVICE_ENDPOINTS[$service]}" ]; then
        http_status=$(check_http_endpoint "${SERVICE_ENDPOINTS[$service]}")
    fi
    
    # Determine overall health
    if [ "$ecs_status" = "ACTIVE" ] && [ "$ecs_running" = "$ecs_desired" ] && [ "$ecs_running" != "0" ] && [ "$tg_healthy" -gt 0 ] && [ "$http_status" = "HEALTHY" ]; then
        print_status "✅ $service"
        echo "   ECS: $ecs_running/$ecs_desired running"
        echo "   ALB: $tg_healthy/$tg_total healthy targets"
        echo "   HTTP: $http_status"
    elif [ "$ecs_status" = "ACTIVE" ] && [ "$ecs_running" = "$ecs_desired" ] && [ "$ecs_running" != "0" ]; then
        print_warning "⚠️  $service"
        echo "   ECS: $ecs_running/$ecs_desired running"
        echo "   ALB: $tg_healthy/$tg_total healthy targets"
        echo "   HTTP: $http_status"
    else
        print_error "❌ $service"
        echo "   ECS: $ecs_status ($ecs_running/$ecs_desired)"
        echo "   ALB: $tg_healthy/$tg_total healthy targets"
        echo "   HTTP: $http_status"
    fi
    echo ""
done

# Show overall status
print_header "Overall Status Summary"

# Count healthy services
healthy_count=0
total_count=${#SERVICES[@]}

for service in "${SERVICES[@]}"; do
    ecs_health=$(check_ecs_service $service)
    IFS='|' read -r ecs_status ecs_running ecs_desired ecs_type <<< "$ecs_health"
    
    tg_health=$(check_target_group_health $service)
    IFS='|' read -r tg_healthy tg_total tg_type <<< "$tg_health"
    
    if [ "$ecs_status" = "ACTIVE" ] && [ "$ecs_running" = "$ecs_desired" ] && [ "$ecs_running" != "0" ] && [ "$tg_healthy" -gt 0 ]; then
        healthy_count=$((healthy_count + 1))
    fi
done

if [ $healthy_count -eq $total_count ]; then
    print_status "🎉 All services are healthy ($healthy_count/$total_count)"
elif [ $healthy_count -gt 0 ]; then
    print_warning "⚠️  Partial health: $healthy_count/$total_count services healthy"
else
    print_error "💥 No services are healthy (0/$total_count)"
fi

# Show resource usage
echo ""
print_header "Resource Usage"

total_tasks=$(aws ecs list-tasks --cluster $CLUSTER_NAME --region $AWS_REGION --query 'length(taskArns)' --output text 2>/dev/null || echo '0')
print_status "Running tasks: $total_tasks"
print_status "Estimated cost: \$$(echo "scale=2; $total_tasks * 0.22" | bc) per hour"

# Show recent events
echo ""
print_header "Recent Service Events (last 10)"

for service in "${SERVICES[@]}"; do
    echo "=== $service ==="
    aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services "$PROJECT_NAME-$service" \
        --region $AWS_REGION \
        --query 'services[0].events[:3].[createdAt,message]' \
        --output table 2>/dev/null || echo "No events found"
    echo ""
done

print_status "Health check completed at $(date)"

# Return appropriate exit code
if [ $healthy_count -eq $total_count ]; then
    exit 0
elif [ $healthy_count -gt 0 ]; then
    exit 1
else
    exit 2
fi 