#!/bin/bash

# Deploy microservices using Helmfile
# Usage: ./deploy-helmfile.sh <environment>

set -e

ENVIRONMENT=${1:-dev}
CLUSTER_NAME="retail-store-${ENVIRONMENT}"

echo "🚀 Deploying microservices to ${ENVIRONMENT} environment..."

# Get IRSA role ARNs from Terraform
echo "🔑 Retrieving IRSA role ARNs..."
cd environments/${ENVIRONMENT}
CART_ROLE_ARN=$(terraform output -raw cart_service_role_arn)
CATALOG_ROLE_ARN=$(terraform output -raw catalog_service_role_arn)
ORDER_ROLE_ARN=$(terraform output -raw order_service_role_arn)
CHECKOUT_ROLE_ARN=$(terraform output -raw checkout_service_role_arn)
cd ../..

# Get database endpoints from Terraform outputs
echo "📋 Retrieving database endpoints..."
cd environments/${ENVIRONMENT}
REDIS_HOST=$(terraform output -json database_endpoints | jq -r '.redis')
MYSQL_HOST=$(terraform output -json database_endpoints | jq -r '.mysql' | cut -d: -f1)
POSTGRES_HOST=$(terraform output -json database_endpoints | jq -r '.postgresql' | cut -d: -f1)
cd ../..

# Get passwords from secrets
REDIS_PASSWORD=$(aws secretsmanager get-secret-value --secret-id ${CLUSTER_NAME}-redis-credentials --query SecretString --output text | jq -r '.password')
MYSQL_USERNAME=$(aws secretsmanager get-secret-value --secret-id ${CLUSTER_NAME}-mysql-credentials --query SecretString --output text | jq -r '.username')
MYSQL_PASSWORD=$(aws secretsmanager get-secret-value --secret-id ${CLUSTER_NAME}-mysql-credentials --query SecretString --output text | jq -r '.password')
POSTGRES_USERNAME=$(aws secretsmanager get-secret-value --secret-id ${CLUSTER_NAME}-postgresql-credentials --query SecretString --output text | jq -r '.username')
POSTGRES_PASSWORD=$(aws secretsmanager get-secret-value --secret-id ${CLUSTER_NAME}-postgresql-credentials --query SecretString --output text | jq -r '.password')

# Deploy using Helmfile with environment variables
echo "📦 Deploying with Helmfile..."
env CART_ROLE_ARN="$CART_ROLE_ARN" \
    CATALOG_ROLE_ARN="$CATALOG_ROLE_ARN" \
    ORDER_ROLE_ARN="$ORDER_ROLE_ARN" \
    CHECKOUT_ROLE_ARN="$CHECKOUT_ROLE_ARN" \
    REDIS_HOST="$REDIS_HOST" \
    REDIS_PASSWORD="$REDIS_PASSWORD" \
    MYSQL_HOST="$MYSQL_HOST" \
    MYSQL_USERNAME="$MYSQL_USERNAME" \
    MYSQL_PASSWORD="$MYSQL_PASSWORD" \
    POSTGRES_HOST="$POSTGRES_HOST" \
    POSTGRES_USERNAME="$POSTGRES_USERNAME" \
    POSTGRES_PASSWORD="$POSTGRES_PASSWORD" \
    ~/bin/helmfile -e ${ENVIRONMENT} sync

echo "✅ Deployment completed for ${ENVIRONMENT} environment!"
echo "🔍 Verify deployment:"
echo "  kubectl get pods -n retail-store-${ENVIRONMENT}"
echo "  kubectl get svc -n retail-store-${ENVIRONMENT}"