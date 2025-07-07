#!/bin/bash

# Setup GitHub Secrets for CI/CD Pipeline
# This script helps configure GitHub repository secrets for the CI/CD pipeline

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

# Function to check if gh CLI is installed
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed. Please install it first:"
        print_error "https://cli.github.com/manual/installation"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        print_error "GitHub CLI is not authenticated. Please run 'gh auth login' first."
        exit 1
    fi
}

# Function to set a GitHub secret
set_github_secret() {
    local secret_name="$1"
    local secret_value="$2"
    local description="$3"
    
    if [ -z "$secret_value" ]; then
        print_warning "Skipping empty secret: $secret_name"
        return
    fi
    
    print_status "Setting secret: $secret_name"
    if echo "$secret_value" | gh secret set "$secret_name" --body-file -; then
        print_status "✅ Successfully set $secret_name"
    else
        print_error "❌ Failed to set $secret_name"
        return 1
    fi
}

# Function to prompt for secret value
prompt_secret() {
    local secret_name="$1"
    local description="$2"
    local default_value="$3"
    
    echo
    print_status "Setting up: $secret_name"
    print_status "Description: $description"
    
    if [ -n "$default_value" ]; then
        read -p "Enter value (default: $default_value): " -r secret_value
        secret_value=${secret_value:-$default_value}
    else
        read -p "Enter value: " -r secret_value
    fi
    
    if [ -n "$secret_value" ]; then
        set_github_secret "$secret_name" "$secret_value" "$description"
    else
        print_warning "No value provided for $secret_name"
    fi
}

# Function to setup AWS secrets
setup_aws_secrets() {
    print_status "Setting up AWS secrets..."
    
    prompt_secret "AWS_ACCESS_KEY_ID" "AWS Access Key ID for deployment" ""
    prompt_secret "AWS_SECRET_ACCESS_KEY" "AWS Secret Access Key for deployment" ""
    prompt_secret "AWS_ACCOUNT_ID" "AWS Account ID" "123456789012"
}

# Function to setup database secrets
setup_database_secrets() {
    print_status "Setting up database secrets..."
    
    prompt_secret "DB_USERNAME" "Database username" "postgres"
    prompt_secret "DB_PASSWORD" "Database password" ""
    prompt_secret "DB_NAME" "Database name" "django_microservices"
}

# Function to setup application secrets
setup_application_secrets() {
    print_status "Setting up application secrets..."
    
    # Generate a random Django secret key
    local django_secret_key=$(python3 -c "import secrets; print(secrets.token_urlsafe(50))")
    prompt_secret "DJANGO_SECRET_KEY" "Django secret key" "$django_secret_key"
    
    # Generate a random JWT secret key
    local jwt_secret_key=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))")
    prompt_secret "JWT_SECRET_KEY" "JWT secret key" "$jwt_secret_key"
}

# Function to setup backup secrets
setup_backup_secrets() {
    print_status "Setting up backup secrets..."
    
    prompt_secret "BACKUP_S3_BUCKET" "S3 bucket for backups" "django-microservices-backups"
}

# Function to setup notification secrets
setup_notification_secrets() {
    print_status "Setting up notification secrets..."
    
    prompt_secret "SLACK_WEBHOOK" "Slack webhook URL for notifications" ""
    prompt_secret "EMAIL_HOST_PASSWORD" "Email host password" ""
}

# Function to setup monitoring secrets
setup_monitoring_secrets() {
    print_status "Setting up monitoring secrets..."
    
    prompt_secret "SENTRY_DSN" "Sentry DSN for error tracking" ""
    prompt_secret "NEWRELIC_LICENSE_KEY" "New Relic license key" ""
    prompt_secret "DATADOG_API_KEY" "Datadog API key" ""
}

# Function to setup environment-specific secrets
setup_environment_secrets() {
    local environment="$1"
    
    print_status "Setting up $environment environment secrets..."
    
    # Load environment file if it exists
    local env_file="$PROJECT_ROOT/ci-cd/environments/$environment.env"
    if [ -f "$env_file" ]; then
        print_status "Loading configuration from $env_file"
        
        # Extract key-value pairs and set as secrets
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            if [[ "$key" =~ ^#.*$ ]] || [[ -z "$key" ]]; then
                continue
            fi
            
            # Remove any quotes from value
            value=$(echo "$value" | sed 's/^["\x27]//' | sed 's/["\x27]$//')
            
            # Skip if value contains placeholder text
            if [[ "$value" =~ change_me|your-|example\.com ]]; then
                print_warning "Skipping placeholder value for $key"
                continue
            fi
            
            # Set secret with environment prefix
            local secret_name="${environment^^}_${key}"
            set_github_secret "$secret_name" "$value" "Environment variable for $environment"
        done < <(grep -E '^[A-Z_]+=.*' "$env_file")
    else
        print_warning "Environment file not found: $env_file"
    fi
}

# Function to validate secrets
validate_secrets() {
    print_status "Validating required secrets..."
    
    local required_secrets=(
        "AWS_ACCESS_KEY_ID"
        "AWS_SECRET_ACCESS_KEY"
        "AWS_ACCOUNT_ID"
        "DB_USERNAME"
        "DB_PASSWORD"
        "DB_NAME"
        "DJANGO_SECRET_KEY"
        "JWT_SECRET_KEY"
        "BACKUP_S3_BUCKET"
    )
    
    for secret in "${required_secrets[@]}"; do
        if gh secret list | grep -q "$secret"; then
            print_status "✅ $secret is configured"
        else
            print_error "❌ $secret is missing"
        fi
    done
}

# Function to display help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Setup GitHub secrets for CI/CD pipeline.

OPTIONS:
    -h, --help              Show this help message
    -a, --aws               Setup AWS secrets only
    -d, --database          Setup database secrets only
    -app, --application     Setup application secrets only
    -b, --backup            Setup backup secrets only
    -n, --notification      Setup notification secrets only
    -m, --monitoring        Setup monitoring secrets only
    -e, --environment ENV   Setup environment-specific secrets (staging/production)
    -v, --validate          Validate existing secrets
    --all                   Setup all secrets (default)

EXAMPLES:
    $0 --all                    # Setup all secrets
    $0 --aws                    # Setup only AWS secrets
    $0 --environment staging    # Setup staging environment secrets
    $0 --validate              # Validate existing secrets

EOF
}

# Main function
main() {
    local setup_all=true
    local setup_aws=false
    local setup_database=false
    local setup_application=false
    local setup_backup=false
    local setup_notification=false
    local setup_monitoring=false
    local setup_environment=""
    local validate_only=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -a|--aws)
                setup_all=false
                setup_aws=true
                shift
                ;;
            -d|--database)
                setup_all=false
                setup_database=true
                shift
                ;;
            -app|--application)
                setup_all=false
                setup_application=true
                shift
                ;;
            -b|--backup)
                setup_all=false
                setup_backup=true
                shift
                ;;
            -n|--notification)
                setup_all=false
                setup_notification=true
                shift
                ;;
            -m|--monitoring)
                setup_all=false
                setup_monitoring=true
                shift
                ;;
            -e|--environment)
                setup_all=false
                setup_environment="$2"
                shift 2
                ;;
            -v|--validate)
                validate_only=true
                shift
                ;;
            --all)
                setup_all=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Check prerequisites
    check_gh_cli
    
    print_status "Setting up GitHub secrets for CI/CD pipeline..."
    print_status "Repository: $(gh repo view --json nameWithOwner --jq .nameWithOwner)"
    
    # Validate only if requested
    if [ "$validate_only" = true ]; then
        validate_secrets
        exit 0
    fi
    
    # Setup secrets based on options
    if [ "$setup_all" = true ]; then
        setup_aws_secrets
        setup_database_secrets
        setup_application_secrets
        setup_backup_secrets
        setup_notification_secrets
        setup_monitoring_secrets
        setup_environment_secrets "staging"
        setup_environment_secrets "production"
    else
        [ "$setup_aws" = true ] && setup_aws_secrets
        [ "$setup_database" = true ] && setup_database_secrets
        [ "$setup_application" = true ] && setup_application_secrets
        [ "$setup_backup" = true ] && setup_backup_secrets
        [ "$setup_notification" = true ] && setup_notification_secrets
        [ "$setup_monitoring" = true ] && setup_monitoring_secrets
        [ -n "$setup_environment" ] && setup_environment_secrets "$setup_environment"
    fi
    
    # Validate secrets
    echo
    validate_secrets
    
    print_status "🎉 GitHub secrets setup completed!"
    print_status "You can now run your CI/CD workflows."
}

# Run main function
main "$@" 