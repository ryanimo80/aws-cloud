#!/bin/bash

# AWS ECS Microservices Monitoring Dashboard
# This script provides a simple monitoring dashboard for ECS services

set -e

# Configuration
PROJECT_NAME="${PROJECT_NAME:-django-microservices}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${PROJECT_NAME}-cluster"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Services to monitor
SERVICES=(
    "api-gateway"
    "user-service"
    "product-service"
    "order-service"
    "notification-service"
)

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    case $status in
        "OK")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}❌ $message${NC}"
            ;;
        "INFO")
            echo -e "${BLUE}ℹ️  $message${NC}"
            ;;
    esac
}

# Function to check if AWS CLI is configured
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_status "ERROR" "AWS CLI is not installed"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_status "ERROR" "AWS CLI is not configured or credentials are invalid"
        exit 1
    fi
    
    print_status "OK" "AWS CLI is configured"
}

# Function to get ECS cluster status
get_cluster_status() {
    echo "=================================================="
    echo "🏗️  ECS CLUSTER STATUS"
    echo "=================================================="
    
    local cluster_info=$(aws ecs describe-clusters \
        --clusters "$CLUSTER_NAME" \
        --region "$AWS_REGION" \
        --query 'clusters[0]' \
        --output json 2>/dev/null)
    
    if [[ $? -eq 0 ]] && [[ "$cluster_info" != "null" ]]; then
        local status=$(echo "$cluster_info" | jq -r '.status')
        local running_tasks=$(echo "$cluster_info" | jq -r '.runningTasksCount')
        local pending_tasks=$(echo "$cluster_info" | jq -r '.pendingTasksCount')
        local services=$(echo "$cluster_info" | jq -r '.activeServicesCount')
        
        print_status "INFO" "Cluster: $CLUSTER_NAME"
        print_status "INFO" "Status: $status"
        print_status "INFO" "Running Tasks: $running_tasks"
        print_status "INFO" "Pending Tasks: $pending_tasks"
        print_status "INFO" "Active Services: $services"
        
        if [[ "$status" == "ACTIVE" ]]; then
            print_status "OK" "Cluster is healthy"
        else
            print_status "WARNING" "Cluster status is $status"
        fi
    else
        print_status "ERROR" "Failed to get cluster information"
    fi
}

# Function to get service status
get_service_status() {
    echo ""
    echo "=================================================="
    echo "🚀 ECS SERVICES STATUS"
    echo "=================================================="
    
    for service in "${SERVICES[@]}"; do
        local service_name="${PROJECT_NAME}-${service}"
        
        echo ""
        echo "📊 Service: $service"
        echo "--------------------------------------------------"
        
        local service_info=$(aws ecs describe-services \
            --cluster "$CLUSTER_NAME" \
            --services "$service_name" \
            --region "$AWS_REGION" \
            --query 'services[0]' \
            --output json 2>/dev/null)
        
        if [[ $? -eq 0 ]] && [[ "$service_info" != "null" ]]; then
            local status=$(echo "$service_info" | jq -r '.status')
            local running_count=$(echo "$service_info" | jq -r '.runningCount')
            local desired_count=$(echo "$service_info" | jq -r '.desiredCount')
            local task_definition=$(echo "$service_info" | jq -r '.taskDefinition' | cut -d'/' -f2)
            
            print_status "INFO" "Status: $status"
            print_status "INFO" "Running: $running_count/$desired_count"
            print_status "INFO" "Task Definition: $task_definition"
            
            if [[ "$status" == "ACTIVE" ]] && [[ "$running_count" -eq "$desired_count" ]]; then
                print_status "OK" "Service is healthy"
            elif [[ "$status" == "ACTIVE" ]] && [[ "$running_count" -lt "$desired_count" ]]; then
                print_status "WARNING" "Service is running but below desired capacity"
            else
                print_status "ERROR" "Service is unhealthy"
            fi
        else
            print_status "ERROR" "Failed to get service information"
        fi
    done
}

# Function to get RDS status
get_rds_status() {
    echo ""
    echo "=================================================="
    echo "🗄️  RDS DATABASE STATUS"
    echo "=================================================="
    
    local db_instance_id="${PROJECT_NAME}-db"
    
    local db_info=$(aws rds describe-db-instances \
        --db-instance-identifier "$db_instance_id" \
        --region "$AWS_REGION" \
        --query 'DBInstances[0]' \
        --output json 2>/dev/null)
    
    if [[ $? -eq 0 ]] && [[ "$db_info" != "null" ]]; then
        local status=$(echo "$db_info" | jq -r '.DBInstanceStatus')
        local engine=$(echo "$db_info" | jq -r '.Engine')
        local instance_class=$(echo "$db_info" | jq -r '.DBInstanceClass')
        local storage=$(echo "$db_info" | jq -r '.AllocatedStorage')
        
        print_status "INFO" "Instance: $db_instance_id"
        print_status "INFO" "Status: $status"
        print_status "INFO" "Engine: $engine"
        print_status "INFO" "Class: $instance_class"
        print_status "INFO" "Storage: ${storage}GB"
        
        if [[ "$status" == "available" ]]; then
            print_status "OK" "Database is healthy"
        else
            print_status "WARNING" "Database status is $status"
        fi
    else
        print_status "ERROR" "Failed to get database information"
    fi
}

# Function to get ElastiCache status
get_redis_status() {
    echo ""
    echo "=================================================="
    echo "🗂️  REDIS CACHE STATUS"
    echo "=================================================="
    
    local redis_cluster_id="${PROJECT_NAME}-redis"
    
    local redis_info=$(aws elasticache describe-cache-clusters \
        --cache-cluster-id "$redis_cluster_id" \
        --region "$AWS_REGION" \
        --query 'CacheClusters[0]' \
        --output json 2>/dev/null)
    
    if [[ $? -eq 0 ]] && [[ "$redis_info" != "null" ]]; then
        local status=$(echo "$redis_info" | jq -r '.CacheClusterStatus')
        local engine=$(echo "$redis_info" | jq -r '.Engine')
        local node_type=$(echo "$redis_info" | jq -r '.CacheNodeType')
        local num_nodes=$(echo "$redis_info" | jq -r '.NumCacheNodes')
        
        print_status "INFO" "Cluster: $redis_cluster_id"
        print_status "INFO" "Status: $status"
        print_status "INFO" "Engine: $engine"
        print_status "INFO" "Node Type: $node_type"
        print_status "INFO" "Nodes: $num_nodes"
        
        if [[ "$status" == "available" ]]; then
            print_status "OK" "Redis cache is healthy"
        else
            print_status "WARNING" "Redis cache status is $status"
        fi
    else
        print_status "ERROR" "Failed to get Redis cache information"
    fi
}

# Function to get Load Balancer status
get_alb_status() {
    echo ""
    echo "=================================================="
    echo "⚖️  LOAD BALANCER STATUS"
    echo "=================================================="
    
    local alb_info=$(aws elbv2 describe-load-balancers \
        --region "$AWS_REGION" \
        --query "LoadBalancers[?contains(LoadBalancerName, '$PROJECT_NAME')]" \
        --output json 2>/dev/null)
    
    if [[ $? -eq 0 ]] && [[ "$alb_info" != "[]" ]]; then
        local alb_name=$(echo "$alb_info" | jq -r '.[0].LoadBalancerName')
        local alb_status=$(echo "$alb_info" | jq -r '.[0].State.Code')
        local alb_type=$(echo "$alb_info" | jq -r '.[0].Type')
        local alb_dns=$(echo "$alb_info" | jq -r '.[0].DNSName')
        
        print_status "INFO" "Load Balancer: $alb_name"
        print_status "INFO" "Status: $alb_status"
        print_status "INFO" "Type: $alb_type"
        print_status "INFO" "DNS: $alb_dns"
        
        if [[ "$alb_status" == "active" ]]; then
            print_status "OK" "Load balancer is healthy"
        else
            print_status "WARNING" "Load balancer status is $alb_status"
        fi
    else
        print_status "ERROR" "Failed to get load balancer information"
    fi
}

# Function to get recent logs
get_recent_logs() {
    echo ""
    echo "=================================================="
    echo "📋 RECENT LOGS (Last 10 minutes)"
    echo "=================================================="
    
    local end_time=$(date +%s)
    local start_time=$((end_time - 600)) # 10 minutes ago
    
    for service in "${SERVICES[@]}"; do
        local log_group="/ecs/${PROJECT_NAME}-${service}"
        
        echo ""
        echo "📄 $service logs:"
        echo "--------------------------------------------------"
        
        local logs=$(aws logs filter-log-events \
            --log-group-name "$log_group" \
            --start-time "${start_time}000" \
            --end-time "${end_time}000" \
            --region "$AWS_REGION" \
            --query 'events[*].message' \
            --output text 2>/dev/null | head -5)
        
        if [[ $? -eq 0 ]] && [[ -n "$logs" ]]; then
            echo "$logs"
        else
            print_status "INFO" "No recent logs or log group not found"
        fi
    done
}

# Function to show cost estimate
show_cost_estimate() {
    echo ""
    echo "=================================================="
    echo "💰 ESTIMATED DAILY COST"
    echo "=================================================="
    
    print_status "INFO" "ECS Fargate (5 services): ~$1.10/day"
    print_status "INFO" "RDS db.t3.micro: ~$0.44/day"
    print_status "INFO" "ElastiCache cache.t3.micro: ~$0.40/day"
    print_status "INFO" "NAT Gateway: ~$1.35/day"
    print_status "INFO" "ALB: ~$0.65/day"
    print_status "INFO" "CloudWatch Logs: ~$0.24/day"
    print_status "INFO" "Total Estimated: ~$4.18/day"
    print_status "WARNING" "Actual costs may vary based on usage"
}

# Function to show help
show_help() {
    echo "AWS ECS Microservices Monitoring Dashboard"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --cluster-only     Show only ECS cluster status"
    echo "  --services-only    Show only ECS services status"
    echo "  --infra-only       Show only infrastructure status"
    echo "  --logs-only        Show only recent logs"
    echo "  --cost-only        Show only cost estimate"
    echo "  --watch            Watch mode (refresh every 30 seconds)"
    echo "  --help             Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  PROJECT_NAME       Project name (default: django-microservices)"
    echo "  ENVIRONMENT        Environment (default: dev)"
    echo "  AWS_REGION         AWS region (default: us-east-1)"
    echo ""
    echo "Examples:"
    echo "  $0                 # Show full dashboard"
    echo "  $0 --services-only # Show only services status"
    echo "  $0 --watch         # Watch mode"
    echo "  PROJECT_NAME=myproject $0 # Use custom project name"
}

# Main function
main() {
    local show_all=true
    local watch_mode=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cluster-only)
                show_all=false
                check_aws_cli
                get_cluster_status
                exit 0
                ;;
            --services-only)
                show_all=false
                check_aws_cli
                get_service_status
                exit 0
                ;;
            --infra-only)
                show_all=false
                check_aws_cli
                get_rds_status
                get_redis_status
                get_alb_status
                exit 0
                ;;
            --logs-only)
                show_all=false
                check_aws_cli
                get_recent_logs
                exit 0
                ;;
            --cost-only)
                show_all=false
                show_cost_estimate
                exit 0
                ;;
            --watch)
                watch_mode=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
    
    # Main dashboard
    if [[ "$show_all" == true ]]; then
        check_aws_cli
        
        if [[ "$watch_mode" == true ]]; then
            echo "Starting watch mode (refresh every 30 seconds)"
            echo "Press Ctrl+C to stop..."
            
            while true; do
                clear
                echo "🌟 AWS ECS MICROSERVICES MONITORING DASHBOARD"
                echo "Project: $PROJECT_NAME | Environment: $ENVIRONMENT | Region: $AWS_REGION"
                echo "Last Updated: $(date)"
                
                get_cluster_status
                get_service_status
                get_rds_status
                get_redis_status
                get_alb_status
                show_cost_estimate
                
                echo ""
                echo "Press Ctrl+C to stop watching..."
                sleep 30
            done
        else
            echo "🌟 AWS ECS MICROSERVICES MONITORING DASHBOARD"
            echo "Project: $PROJECT_NAME | Environment: $ENVIRONMENT | Region: $AWS_REGION"
            echo "Timestamp: $(date)"
            
            get_cluster_status
            get_service_status
            get_rds_status
            get_redis_status
            get_alb_status
            show_cost_estimate
            
            echo ""
            echo "💡 Use --help for more options"
        fi
    fi
}

# Run main function
main "$@" 